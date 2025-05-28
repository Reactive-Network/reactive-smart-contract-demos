// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';
import '../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import '../../../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';

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
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
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
}

contract AaveLiquidationProtectionCallback is AbstractCallback {

    event PositionProtected(
        address indexed user,
        address indexed lendingPool,
        uint256 newHealthFactor,
        uint256 collateralAdded
    );
    event ProtectionFailed(
        address indexed user,
        address indexed lendingPool,
        string reason
    );
    event DebugCalculation(
        uint256 currentHF,
        uint256 targetHF,
        uint256 currentWeightedCollateral,
        uint256 requiredWeightedCollateral,
        uint256 additionalCollateralUSD,
        int256 collateralPrice,
        uint256 collateralNeeded,
        uint256 collateralLiquidationThreshold
    );

    address private collateralToken;
    address private owner;
    address private protocolDataProvider;
    AggregatorV3Interface internal collateralTokenPriceFeed;

    constructor(
        address _callback_sender,
        address _collateralToken,
        address _collateralTokenPriceFeed,
        address _protocolDataProvider
    ) AbstractCallback(_callback_sender) payable {
        collateralToken = _collateralToken;
        collateralTokenPriceFeed = AggregatorV3Interface(_collateralTokenPriceFeed);
        protocolDataProvider = _protocolDataProvider;
        owner = msg.sender;
    }

    function protectPosition(
        address /* sender */,
        address user,
        address lendingPool,
        uint256 targetHealthFactor,
        uint256 healthFactorThreshold
    ) external authorizedSenderOnly {
        (,,,,, uint256 currentHealthFactor) = ILendingPool(lendingPool).getUserAccountData(user);
        try this._executeProtection(user, lendingPool, targetHealthFactor, healthFactorThreshold, currentHealthFactor) 
        returns (uint256 collateralAdded) {
            (,,,,, uint256 finalHealthFactor) = ILendingPool(lendingPool).getUserAccountData(user);
            emit PositionProtected(user, lendingPool, finalHealthFactor, collateralAdded);
        } catch Error(string memory reason) {
            emit ProtectionFailed(user, lendingPool, reason);
            emit PositionProtected(user, lendingPool, currentHealthFactor, 0);
        } catch {
            emit ProtectionFailed(user, lendingPool, "Unknown error");
            emit PositionProtected(user, lendingPool, currentHealthFactor, 0);
        }
    }

    function _executeProtection(
        address user,
        address lendingPool,
        uint256 targetHealthFactor,
        uint256 healthFactorThreshold,
        uint256 currentHealthFactor
    ) external returns (uint256) {
        require(msg.sender == address(this), "Internal function");
        if (currentHealthFactor >= healthFactorThreshold) {
            return 0;
        }
        (, uint256 totalDebtUSD,,,,) = ILendingPool(lendingPool).getUserAccountData(user);
        if (totalDebtUSD == 0) {
            return 0;
        }
        uint256 collateralNeeded = calculateCollateralNeeded(
            user, 
            lendingPool, 
            targetHealthFactor
        );
        if (collateralNeeded > 0) {
            uint256 approvedAmount = IERC20(collateralToken).allowance(user, address(this));
            require(approvedAmount >= collateralNeeded, "Insufficient approved collateral");
            uint256 userBalance = IERC20(collateralToken).balanceOf(user);
            require(userBalance >= collateralNeeded, "Insufficient user balance");
            IERC20(collateralToken).transferFrom(user, address(this), collateralNeeded);
            IERC20(collateralToken).approve(lendingPool, collateralNeeded);
            ILendingPool(lendingPool).supply(
                collateralToken,
                collateralNeeded,
                user,
                0
            );
        }
        return collateralNeeded;
    }

    function calculateCollateralNeeded(
        address user,
        address lendingPool,
        uint256 targetHealthFactor
    ) internal view returns (uint256) {
        (uint256 totalCollateralUSD, uint256 totalDebtUSD, , uint256 currentLiquidationThreshold, , uint256 currentHealthFactor) = 
            ILendingPool(lendingPool).getUserAccountData(user);
        if (totalDebtUSD == 0 || currentHealthFactor >= targetHealthFactor) {
            return 0;
        }
        uint256 collateralLiquidationThreshold = getCollateralLiquidationThreshold();
        uint256 currentWeightedCollateral = (totalCollateralUSD * currentLiquidationThreshold) / 10000;
        uint256 targetHF_BasisPoints = targetHealthFactor / 1e14;
        uint256 requiredWeightedCollateral = (targetHF_BasisPoints * totalDebtUSD) / 10000;
        if (requiredWeightedCollateral <= currentWeightedCollateral) {
            return 0;
        }
        uint256 additionalWeightedCollateral = requiredWeightedCollateral - currentWeightedCollateral;
        uint256 additionalCollateralUSD = (additionalWeightedCollateral * 10000) / collateralLiquidationThreshold;
        (, int256 collateralPriceUSD,,,) = collateralTokenPriceFeed.latestRoundData();
        require(collateralPriceUSD > 0, "Invalid collateral price from feed");
        uint256 collateralNeeded = (additionalCollateralUSD * 1e18) / uint256(collateralPriceUSD);
        return collateralNeeded;
    }

    function getCollateralLiquidationThreshold() internal view returns (uint256) {
        (,, uint256 liquidationThreshold,,,,,,,) = IProtocolDataProvider(protocolDataProvider)
            .getReserveConfigurationData(collateralToken);
        return liquidationThreshold;
    }
}