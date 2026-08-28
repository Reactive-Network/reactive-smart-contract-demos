// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./RescuableBase.sol";
import "./AISentinelRiskEngine.sol";

interface IERC20Detailed is IERC20 {
    function decimals() external view returns (uint8);
}

interface ILendingPool {
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256);
}

interface IProtocolDataProvider {
    function getReserveConfigurationData(address asset)
        external
        view
        returns (
            uint256 decimals,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        );

    function getUserReserveData(address asset, address user)
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        );
}

interface IPriceOracleGetter {
    function getAssetPrice(address asset) external view returns (uint256);
    function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory);
}

interface ILendingPoolAddressesProvider {
    function getPriceOracle() external view returns (address);
}

contract AaveProtectionDemoCallback is AbstractCallback, RescuableBase {
    using SafeERC20 for IERC20;

    enum ProtectionType {
        COLLATERAL_DEPOSIT,
        DEBT_REPAYMENT,
        BOTH
    }

    enum ProtectionStatus {
        Active,
        Paused,
        Cancelled
    }

    struct ProtectionConfig {
        uint256 id;
        ProtectionType protectionType;
        uint256 healthFactorThreshold;
        uint256 targetHealthFactor;
        address collateralAsset;
        address debtAsset;
        bool preferDebtRepayment;
        ProtectionStatus status;
        uint256 createdAt;
        uint256 lastExecutedAt;
        uint8 executionCount;
        uint256 lastExecutionAttempt;
    }

    event ProtectionConfigured(
        uint256 indexed configId,
        ProtectionType protectionType,
        uint256 healthFactorThreshold,
        uint256 targetHealthFactor,
        address collateralAsset,
        address debtAsset
    );

    event ProtectionExecuted(
        uint256 indexed configId,
        string protectionMethod,
        address asset,
        uint256 amount,
        uint256 previousHealthFactor,
        uint256 newHealthFactor
    );

    event AISentinelRiskEvaluated(
        uint256 indexed configId,
        uint256 riskScore,
        AISentinelRiskEngine.RiskRegime regime,
        AISentinelRiskEngine.RecommendedAction action,
        string reason
    );

    event ProtectionCheckFailed(uint256 indexed configId, string reason);
    event ProtectionPaused(uint256 indexed configId);
    event ProtectionResumed(uint256 indexed configId);
    event ProtectionCancelled(uint256 indexed configId);
    event ProtectionCycleCompleted(uint256 timestamp, uint256 totalConfigsChecked, uint256 protectionsExecuted);

    error ProtectionNotActive(uint256 configId);
    error HealthFactorAboveThreshold(uint256 configId);
    error MaxRetriesExceeded(uint256 configId);
    error InsufficientBalanceOrAllowance(uint256 configId);
    error ProtectionExecutionFailed(uint256 configId);

    address public immutable owner;
    address public immutable lendingPool;
    address public immutable protocolDataProvider;
    address public immutable addressesProvider;

    AISentinelRiskEngine public riskEngine;

    ProtectionConfig[] public protectionConfigs;
    uint256 public nextConfigId;

    uint256 private constant RATE_MODE_VARIABLE = 2;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint8 private constant MAX_RETRIES = 3;
    uint256 private constant RETRY_COOLDOWN = 30;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier validConfig(uint256 configId) {
        require(configId < protectionConfigs.length, "Config does not exist");
        _;
    }

    constructor(
        address _owner,
        address _callbackSender,
        address _lendingPool,
        address _protocolDataProvider,
        address _addressesProvider
    ) payable AbstractCallback(_callbackSender) {
        owner = _owner;
        lendingPool = _lendingPool;
        protocolDataProvider = _protocolDataProvider;
        addressesProvider = _addressesProvider;

        riskEngine = new AISentinelRiskEngine();
    }

    function createProtectionConfig(
        ProtectionType _protectionType,
        uint256 _healthFactorThreshold,
        uint256 _targetHealthFactor,
        address _collateralAsset,
        address _debtAsset,
        bool _preferDebtRepayment
    ) external onlyOwner returns (uint256) {
        require(_healthFactorThreshold > MIN_HEALTH_FACTOR, "Threshold too low");
        require(_targetHealthFactor > _healthFactorThreshold, "Target must be higher than threshold");
        require(_collateralAsset != address(0), "Invalid collateral asset");
        require(_debtAsset != address(0), "Invalid debt asset");

        require(_validateAssetSupported(_collateralAsset), "Collateral asset not supported");
        require(_validateAssetSupported(_debtAsset), "Debt asset not supported");

        uint256 configId = nextConfigId;

        protectionConfigs.push(
            ProtectionConfig({
                id: configId,
                protectionType: _protectionType,
                healthFactorThreshold: _healthFactorThreshold,
                targetHealthFactor: _targetHealthFactor,
                collateralAsset: _collateralAsset,
                debtAsset: _debtAsset,
                preferDebtRepayment: _preferDebtRepayment,
                status: ProtectionStatus.Active,
                createdAt: block.timestamp,
                lastExecutedAt: 0,
                executionCount: 0,
                lastExecutionAttempt: 0
            })
        );

        nextConfigId++;

        emit ProtectionConfigured(
            configId,
            _protectionType,
            _healthFactorThreshold,
            _targetHealthFactor,
            _collateralAsset,
            _debtAsset
        );

        return configId;
    }

    function checkAndProtectPositions(address /*sender*/) external authorizedSenderOnly {
        uint256 totalConfigsChecked = 0;
        uint256 protectionsExecuted = 0;

        for (uint256 i = 0; i < protectionConfigs.length; i++) {
            ProtectionConfig storage config = protectionConfigs[i];

            if (config.status != ProtectionStatus.Active) {
                continue;
            }

            totalConfigsChecked++;

            try this._checkAndProtectConfig(i) returns (bool wasProtected) {
                if (wasProtected) {
                    protectionsExecuted++;
                }
            } catch {
                emit ProtectionCheckFailed(i, "Unexpected error during protection check");
            }
        }

        emit ProtectionCycleCompleted(block.timestamp, totalConfigsChecked, protectionsExecuted);
    }

    function _checkAndProtectConfig(uint256 configId) external returns (bool) {
        require(msg.sender == address(this), "Internal function");

        ProtectionConfig storage config = protectionConfigs[configId];

        (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,,,,
            uint256 currentHealthFactor
        ) = ILendingPool(lendingPool).getUserAccountData(owner);

        AISentinelRiskEngine.RiskInput memory input =
            AISentinelRiskEngine.RiskInput({
                healthFactor: currentHealthFactor,
                healthFactorThreshold: config.healthFactorThreshold,
                targetHealthFactor: config.targetHealthFactor,
                totalCollateralUSD: totalCollateralUSD,
                totalDebtUSD: totalDebtUSD,
                volatilityScore: 0,
                liquidityScore: 0,
                marketRiskScore: 0,
                oracleDeviationScore: 0,
                whaleFlowScore: 0,
                chainCongestionScore: 0,
                protocolRiskScore: 0,
                failedExecutionCount: config.executionCount,
                timeSinceLastExecution: config.lastExecutedAt == 0
                    ? type(uint256).max
                    : block.timestamp - config.lastExecutedAt,
                priceOracleHealthy: true,
                automationPaused: config.status == ProtectionStatus.Paused
            });

        AISentinelRiskEngine.RiskResult memory riskResult = riskEngine.calculateRisk(input);

        emit AISentinelRiskEvaluated(
            configId,
            riskResult.riskScore,
            riskResult.regime,
            riskResult.action,
            riskResult.reason
        );

        if (
            riskResult.action == AISentinelRiskEngine.RecommendedAction.NO_ACTION ||
            riskResult.action == AISentinelRiskEngine.RecommendedAction.ALERT_ONLY ||
            riskResult.action == AISentinelRiskEngine.RecommendedAction.PAUSE_AUTOMATION
        ) {
            return false;
        }

        if (currentHealthFactor >= config.healthFactorThreshold && riskResult.riskScore < 76) {
            return false;
        }

        if (config.lastExecutionAttempt > 0 && block.timestamp < config.lastExecutionAttempt + RETRY_COOLDOWN) {
            return false;
        }

        if (config.executionCount >= MAX_RETRIES) {
            config.status = ProtectionStatus.Cancelled;
            emit ProtectionCheckFailed(configId, "Max retries exceeded");
            return false;
        }

        config.lastExecutionAttempt = block.timestamp;

        bool protectionExecuted = false;

        if (riskResult.action == AISentinelRiskEngine.RecommendedAction.ADD_COLLATERAL) {
            protectionExecuted = _executeCollateralProtection(configId, currentHealthFactor);
        } else if (riskResult.action == AISentinelRiskEngine.RecommendedAction.REPAY_DEBT) {
            protectionExecuted = _executeDebtRepayment(configId, currentHealthFactor);
        } else if (
            riskResult.action == AISentinelRiskEngine.RecommendedAction.BOTH ||
            riskResult.action == AISentinelRiskEngine.RecommendedAction.EMERGENCY
        ) {
            if (config.preferDebtRepayment) {
                protectionExecuted = _executeDebtRepayment(configId, currentHealthFactor);
                if (!protectionExecuted) {
                    protectionExecuted = _executeCollateralProtection(configId, currentHealthFactor);
                }
            } else {
                protectionExecuted = _executeCollateralProtection(configId, currentHealthFactor);
                if (!protectionExecuted) {
                    protectionExecuted = _executeDebtRepayment(configId, currentHealthFactor);
                }
            }
        } else {
            if (config.protectionType == ProtectionType.COLLATERAL_DEPOSIT) {
                protectionExecuted = _executeCollateralProtection(configId, currentHealthFactor);
            } else if (config.protectionType == ProtectionType.DEBT_REPAYMENT) {
                protectionExecuted = _executeDebtRepayment(configId, currentHealthFactor);
            } else if (config.protectionType == ProtectionType.BOTH) {
                if (config.preferDebtRepayment) {
                    protectionExecuted = _executeDebtRepayment(configId, currentHealthFactor);
                    if (!protectionExecuted) {
                        protectionExecuted = _executeCollateralProtection(configId, currentHealthFactor);
                    }
                } else {
                    protectionExecuted = _executeCollateralProtection(configId, currentHealthFactor);
                    if (!protectionExecuted) {
                        protectionExecuted = _executeDebtRepayment(configId, currentHealthFactor);
                    }
                }
            }
        }

        if (protectionExecuted) {
            config.lastExecutedAt = block.timestamp;
            config.executionCount++;
        }

        return protectionExecuted;
    }

    function cancelProtectionConfig(uint256 configId) external onlyOwner validConfig(configId) {
        ProtectionConfig storage config = protectionConfigs[configId];

        require(
            config.status == ProtectionStatus.Active || config.status == ProtectionStatus.Paused,
            "Cannot cancel config"
        );

        config.status = ProtectionStatus.Cancelled;
        emit ProtectionCancelled(configId);
    }

    function pauseProtectionConfig(uint256 configId) external onlyOwner validConfig(configId) {
        ProtectionConfig storage config = protectionConfigs[configId];

        require(config.status == ProtectionStatus.Active, "Config is not active");

        config.status = ProtectionStatus.Paused;
        emit ProtectionPaused(configId);
    }

    function resumeProtectionConfig(uint256 configId) external onlyOwner validConfig(configId) {
        ProtectionConfig storage config = protectionConfigs[configId];

        require(config.status == ProtectionStatus.Paused, "Config is not paused");

        config.status = ProtectionStatus.Active;
        emit ProtectionResumed(configId);
    }

    function getAllConfigs() external view returns (uint256[] memory) {
        uint256[] memory allConfigIds = new uint256[](protectionConfigs.length);

        for (uint256 i = 0; i < protectionConfigs.length; i++) {
            allConfigIds[i] = i;
        }

        return allConfigIds;
    }

    function getActiveConfigs() external view returns (uint256[] memory) {
        uint256 activeCount = 0;

        for (uint256 i = 0; i < protectionConfigs.length; i++) {
            if (protectionConfigs[i].status == ProtectionStatus.Active) {
                activeCount++;
            }
        }

        uint256[] memory activeConfigs = new uint256[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < protectionConfigs.length; i++) {
            if (protectionConfigs[i].status == ProtectionStatus.Active) {
                activeConfigs[index] = i;
                index++;
            }
        }

        return activeConfigs;
    }

    function previewAISentinelRisk(
        uint256 configId,
        uint256 volatilityScore,
        uint256 liquidityScore,
        uint256 marketRiskScore,
        uint256 oracleDeviationScore,
        uint256 whaleFlowScore,
        uint256 chainCongestionScore,
        uint256 protocolRiskScore,
        bool priceOracleHealthy
    )
        external
        returns (AISentinelRiskEngine.RiskResult memory)
    {
        require(configId < protectionConfigs.length, "Config does not exist");

        ProtectionConfig storage config = protectionConfigs[configId];

        (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,,,,
            uint256 currentHealthFactor
        ) = ILendingPool(lendingPool).getUserAccountData(owner);

        AISentinelRiskEngine.RiskInput memory input =
            AISentinelRiskEngine.RiskInput({
                healthFactor: currentHealthFactor,
                healthFactorThreshold: config.healthFactorThreshold,
                targetHealthFactor: config.targetHealthFactor,
                totalCollateralUSD: totalCollateralUSD,
                totalDebtUSD: totalDebtUSD,
                volatilityScore: volatilityScore,
                liquidityScore: liquidityScore,
                marketRiskScore: marketRiskScore,
                oracleDeviationScore: oracleDeviationScore,
                whaleFlowScore: whaleFlowScore,
                chainCongestionScore: chainCongestionScore,
                protocolRiskScore: protocolRiskScore,
                failedExecutionCount: config.executionCount,
                timeSinceLastExecution: config.lastExecutedAt == 0
                    ? type(uint256).max
                    : block.timestamp - config.lastExecutedAt,
                priceOracleHealthy: priceOracleHealthy,
                automationPaused: config.status == ProtectionStatus.Paused
            });

        AISentinelRiskEngine.RiskResult memory result = riskEngine.calculateRisk(input);

        emit AISentinelRiskEvaluated(
            configId,
            result.riskScore,
            result.regime,
            result.action,
            result.reason
        );

        return result;
    }

    function _executeCollateralProtection(uint256 configId, uint256 currentHealthFactor) internal returns (bool) {
        try this._performCollateralProtection(configId) returns (uint256 collateralAdded) {
            if (collateralAdded > 0) {
                ProtectionConfig storage config = protectionConfigs[configId];
                (,,,,, uint256 finalHealthFactor) = ILendingPool(lendingPool).getUserAccountData(owner);

                emit ProtectionExecuted(
                    configId,
                    "Collateral Deposit",
                    config.collateralAsset,
                    collateralAdded,
                    currentHealthFactor,
                    finalHealthFactor
                );

                return true;
            }

            return false;
        } catch Error(string memory reason) {
            emit ProtectionCheckFailed(configId, string(abi.encodePacked("Collateral protection failed: ", reason)));
            return false;
        } catch {
            emit ProtectionCheckFailed(configId, "Collateral protection failed: Unknown error");
            return false;
        }
    }

    function _executeDebtRepayment(uint256 configId, uint256 currentHealthFactor) internal returns (bool) {
        try this._performDebtRepayment(configId) returns (uint256 repaymentAmount) {
            if (repaymentAmount > 0) {
                ProtectionConfig storage config = protectionConfigs[configId];
                (,,,,, uint256 finalHealthFactor) = ILendingPool(lendingPool).getUserAccountData(owner);

                emit ProtectionExecuted(
                    configId,
                    "Debt Repayment",
                    config.debtAsset,
                    repaymentAmount,
                    currentHealthFactor,
                    finalHealthFactor
                );

                return true;
            }

            return false;
        } catch Error(string memory reason) {
            emit ProtectionCheckFailed(configId, string(abi.encodePacked("Debt repayment failed: ", reason)));
            return false;
        } catch {
            emit ProtectionCheckFailed(configId, "Debt repayment failed: Unknown error");
            return false;
        }
    }

    function _performCollateralProtection(uint256 configId) external returns (uint256) {
        require(msg.sender == address(this), "Internal function");

        ProtectionConfig storage config = protectionConfigs[configId];

        (, uint256 totalDebtUSD,,,,) = ILendingPool(lendingPool).getUserAccountData(owner);

        if (totalDebtUSD == 0) {
            return 0;
        }

        uint256 collateralNeeded = _calculateCollateralNeeded(configId);

        if (collateralNeeded > 0) {
            uint256 userBalance = IERC20(config.collateralAsset).balanceOf(owner);
            require(userBalance >= collateralNeeded, "Insufficient user balance for collateral");

            uint256 approvedAmount = IERC20(config.collateralAsset).allowance(owner, address(this));
            require(approvedAmount >= collateralNeeded, "Insufficient approved collateral");

            IERC20(config.collateralAsset).safeTransferFrom(owner, address(this), collateralNeeded);
            IERC20(config.collateralAsset).forceApprove(lendingPool, collateralNeeded);

            ILendingPool(lendingPool).supply(config.collateralAsset, collateralNeeded, owner, 0);
        }

        return collateralNeeded;
    }

    function _performDebtRepayment(uint256 configId) external returns (uint256) {
        require(msg.sender == address(this), "Internal function");

        ProtectionConfig storage config = protectionConfigs[configId];

        (,, uint256 currentVariableDebt,,,,,,) =
            IProtocolDataProvider(protocolDataProvider).getUserReserveData(config.debtAsset, owner);

        if (currentVariableDebt == 0) {
            return 0;
        }

        uint256 repaymentAmount = _calculateRepaymentAmount(configId);

        if (repaymentAmount > 0) {
            uint256 userBalance = IERC20(config.debtAsset).balanceOf(owner);
            require(userBalance >= repaymentAmount, "Insufficient user balance for repayment");

            uint256 approvedAmount = IERC20(config.debtAsset).allowance(owner, address(this));
            require(approvedAmount >= repaymentAmount, "Insufficient approved debt asset");

            IERC20(config.debtAsset).safeTransferFrom(owner, address(this), repaymentAmount);
            IERC20(config.debtAsset).forceApprove(lendingPool, repaymentAmount);

            ILendingPool(lendingPool).repay(config.debtAsset, repaymentAmount, RATE_MODE_VARIABLE, owner);
        }

        return repaymentAmount;
    }

    function _calculateCollateralNeeded(uint256 configId) internal view returns (uint256) {
        ProtectionConfig storage config = protectionConfigs[configId];

        (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,,
            uint256 currentLiquidationThreshold,,
            uint256 currentHealthFactor
        ) = ILendingPool(lendingPool).getUserAccountData(owner);

        if (totalDebtUSD == 0 || currentHealthFactor >= config.targetHealthFactor) {
            return 0;
        }

        uint256 collateralLiquidationThreshold = _getAssetLiquidationThreshold(config.collateralAsset);
        uint256 currentWeightedCollateral = (totalCollateralUSD * currentLiquidationThreshold) / 10000;
        uint256 targetHF_BasisPoints = config.targetHealthFactor / 1e14;
        uint256 requiredWeightedCollateral = (targetHF_BasisPoints * totalDebtUSD) / 10000;

        if (requiredWeightedCollateral <= currentWeightedCollateral) {
            return 0;
        }

        uint256 additionalWeightedCollateral = requiredWeightedCollateral - currentWeightedCollateral;
        uint256 additionalCollateralUSD = (additionalWeightedCollateral * 10000) / collateralLiquidationThreshold;

        uint256 collateralPriceUSD = _getAssetPrice(config.collateralAsset);
        require(collateralPriceUSD > 0, "Invalid collateral price from Aave oracle");

        uint256 collateralNeeded = (additionalCollateralUSD * 1e18) / collateralPriceUSD;

        return collateralNeeded;
    }

    function _calculateRepaymentAmount(uint256 configId) internal view returns (uint256) {
        ProtectionConfig storage config = protectionConfigs[configId];

        (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,,
            uint256 currentLiquidationThreshold,,
            uint256 currentHealthFactor
        ) = ILendingPool(lendingPool).getUserAccountData(owner);

        if (totalDebtUSD == 0 || currentHealthFactor >= config.targetHealthFactor) {
            return 0;
        }

        uint256 weightedCollateral = (totalCollateralUSD * currentLiquidationThreshold) / 10000;
        uint256 targetDebtUSD = (weightedCollateral * 10000) / (config.targetHealthFactor / 1e14);

        if (totalDebtUSD <= targetDebtUSD) {
            return 0;
        }

        (,, uint256 currentVariableDebt,,,,,,) =
            IProtocolDataProvider(protocolDataProvider).getUserReserveData(config.debtAsset, owner);

        if (currentVariableDebt == 0) {
            return 0;
        }

        uint256 debtToRepayUSD = totalDebtUSD - targetDebtUSD;

        uint256 debtAssetPriceUSD = _getAssetPrice(config.debtAsset);
        require(debtAssetPriceUSD > 0, "Invalid debt asset price from Aave oracle");

        uint8 decimals = IERC20Detailed(config.debtAsset).decimals();
        uint256 assetDebtUSD = (debtAssetPriceUSD * currentVariableDebt) / (10 ** decimals);

        uint256 tokensToRepay;

        if (assetDebtUSD <= debtToRepayUSD) {
            tokensToRepay = currentVariableDebt;
        } else {
            tokensToRepay = (debtToRepayUSD * currentVariableDebt) / assetDebtUSD;
        }

        if (tokensToRepay > currentVariableDebt) {
            tokensToRepay = currentVariableDebt;
        }

        return tokensToRepay;
    }

    function _getAssetLiquidationThreshold(address asset) internal view returns (uint256) {
        (,, uint256 liquidationThreshold,,,,,,,) =
            IProtocolDataProvider(protocolDataProvider).getReserveConfigurationData(asset);

        return liquidationThreshold;
    }

    function _getAssetPrice(address asset) internal view returns (uint256) {
        address priceOracleAddress = ILendingPoolAddressesProvider(addressesProvider).getPriceOracle();
        return IPriceOracleGetter(priceOracleAddress).getAssetPrice(asset);
    }

    function _validateAssetSupported(address asset) internal view returns (bool) {
        try this.getAssetPrice(asset) returns (uint256 price) {
            return price > 0;
        } catch {
            return false;
        }
    }

    function getCurrentHealthFactor() external view returns (uint256) {
        (,,,,, uint256 healthFactor) = ILendingPool(lendingPool).getUserAccountData(owner);
        return healthFactor;
    }

    function getAssetPrice(address asset) external view returns (uint256) {
        return _getAssetPrice(asset);
    }

    function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory) {
        address priceOracleAddress = ILendingPoolAddressesProvider(addressesProvider).getPriceOracle();
        return IPriceOracleGetter(priceOracleAddress).getAssetsPrices(assets);
    }

    function _rescueRecipient() internal view override returns (address) {
        return owner;
    }

    function rescueETH(uint256 amount) external override onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        _rescueETH(amount);
    }

    function rescueAllETH() external override onlyOwner {
        _rescueETH(0);
    }

    function rescueERC20(address token, uint256 amount) external override onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        _rescueERC20(token, amount);
    }

    function rescueAllERC20(address token) external override onlyOwner {
        _rescueERC20(token, 0);
    }
}