// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol";
import "./RescuableBase.sol";

/// @title Aave V3 Oracle Interface
interface IAaveOracle {
    /// @notice Returns the asset price in the base currency (USD, 8 decimals)
    function getAssetPrice(address asset) external view returns (uint256);
}

/// @title Aave V3 Pool Interface (essential functions)
interface IPool {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function getUserAccountData(
        address user
    )
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

/// @title Uniswap V3 SwapRouter02 Interface (no deadline in struct)
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

/// @title LeverageAccount - User's leveraged position vault with Aave V3 Oracle
/// @notice Receives callbacks from Reactive Network to execute leverage loops
contract LeverageAccount is
    AbstractCallback,
    Ownable,
    ReentrancyGuard,
    RescuableBase
{
    using SafeERC20 for IERC20;

    // Protocol contracts
    IPool public aavePool;
    ISwapRouter public swapRouter;
    IAaveOracle public aaveOracle;
    address public callbackProxy;

    // Oracle constants
    uint256 public constant ORACLE_DECIMALS = 8; // Aave oracle returns 8-decimal USD prices
    uint256 public constant PRICE_DECIMALS = 18; // Internal price precision

    // Swap configuration
    uint24 public defaultPoolFee = 500; // 0.05% pool fee
    uint256 public slippageTolerance = 2500; // 25% (in basis points, high for testnet)

    // Authorization
    address public rscCaller;

    // Aave constants
    uint256 private constant VARIABLE_INTEREST_RATE_MODE = 2;
    uint16 private constant REFERRAL_CODE = 0;

    // Events
    event Deposited(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 valueInUSD,
        uint256 healthFactor,
        uint8 tokenDecimals
    );

    event LoopStepExecuted(
        uint256 borrowed,
        uint256 newCollateral,
        uint256 newCollateralValueUSD,
        uint256 healthFactor,
        uint256 iterationId,
        uint8 borrowAssetDecimals
    );

    event PositionClosed(
        uint256 debtRepaid,
        uint256 collateralReturned,
        uint256 finalHealthFactor
    );

    event SlippageConfigured(uint256 newTolerance);
    event PoolFeeUpdated(uint24 newFee);

    constructor(
        address _aavePool,
        address _swapRouter,
        address _aaveOracle,
        address _callbackProxy,
        address _rscCaller
    ) payable AbstractCallback(_callbackProxy) Ownable(msg.sender) {
        require(_aavePool != address(0), "Invalid Aave pool");
        require(_swapRouter != address(0), "Invalid swap router");
        require(_aaveOracle != address(0), "Invalid oracle");
        require(_callbackProxy != address(0), "Invalid callback proxy");
        aavePool = IPool(_aavePool);
        swapRouter = ISwapRouter(_swapRouter);
        aaveOracle = IAaveOracle(_aaveOracle);
        callbackProxy = _callbackProxy;
        rscCaller = _rscCaller;
    }

    modifier onlyController(address sender) {
        require(
            msg.sender == owner() ||
                (msg.sender == callbackProxy && sender == rscCaller),
            "Not authorized"
        );
        _;
    }

    /// @notice Configure slippage tolerance
    /// @param _slippageBps Slippage in basis points (200 = 2%)
    function setSlippageTolerance(uint256 _slippageBps) external onlyOwner {
        require(_slippageBps <= 5000, "Slippage too high"); // Max 50%
        slippageTolerance = _slippageBps;
        emit SlippageConfigured(_slippageBps);
    }

    /// @notice Configure Uniswap pool fee tier
    /// @param _fee Fee tier (500 = 0.05%, 3000 = 0.3%, 10000 = 1%)
    function setPoolFee(uint24 _fee) external onlyOwner {
        require(
            _fee == 500 || _fee == 3000 || _fee == 10000,
            "Invalid fee tier"
        );
        defaultPoolFee = _fee;
        emit PoolFeeUpdated(_fee);
    }

    /// @notice Get asset price from Aave V3 Oracle (18 decimal precision)
    /// @param asset The token address
    /// @return price The asset price in USD (18 decimals)
    function getAssetPrice(address asset) public view returns (uint256 price) {
        uint256 oraclePrice = aaveOracle.getAssetPrice(asset); // 8 decimals
        require(oraclePrice > 0, "Invalid price");
        // Scale from 8 decimals to 18 decimals
        price = oraclePrice * (10 ** (PRICE_DECIMALS - ORACLE_DECIMALS));
    }

    /// @notice Calculate USD value of a token amount
    /// @param asset The token address
    /// @param amount The token amount (in token's native decimals)
    /// @return valueUSD The USD value (18 decimals)
    function getValueInUSD(
        address asset,
        uint256 amount
    ) public view returns (uint256 valueUSD) {
        uint256 price = getAssetPrice(asset); // 18 decimals
        uint8 tokenDecimals = IERC20Metadata(asset).decimals();
        valueUSD = (amount * price) / (10 ** tokenDecimals);
    }

    /// @notice Calculate minimum output for a swap with slippage protection
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param amountIn Input amount
    /// @return minAmountOut Minimum acceptable output (with slippage)
    function calculateMinOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256 minAmountOut) {
        uint256 priceIn = getAssetPrice(tokenIn); // 18 decimals
        uint256 priceOut = getAssetPrice(tokenOut); // 18 decimals

        uint8 decimalsIn = IERC20Metadata(tokenIn).decimals();
        uint8 decimalsOut = IERC20Metadata(tokenOut).decimals();

        uint256 expectedOut = (amountIn * priceIn * (10 ** decimalsOut)) /
            (priceOut * (10 ** decimalsIn));

        minAmountOut = (expectedOut * (10000 - slippageTolerance)) / 10000;
    }

    /// @notice Update RSC caller address
    function setRSCCaller(address _rscCaller) external onlyOwner {
        rscCaller = _rscCaller;
    }

    /// @notice Update Aave oracle address
    function setAaveOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle");
        aaveOracle = IAaveOracle(_oracle);
    }

    /// @notice Deposit collateral with USD value calculation
    /// @param token The collateral token (e.g., WETH)
    /// @param amount The amount to deposit
    function deposit(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 valueInUSD = getValueInUSD(token, amount);
        uint8 tokenDecimals = IERC20Metadata(token).decimals();

        IERC20(token).forceApprove(address(aavePool), amount);
        aavePool.supply(token, amount, address(this), REFERRAL_CODE);

        (, , , , , uint256 healthFactor) = aavePool.getUserAccountData(
            address(this)
        );

        emit Deposited(
            msg.sender,
            token,
            amount,
            valueInUSD,
            healthFactor,
            tokenDecimals
        );
    }

    /// @notice Deposit with EIP-2612 permit (gasless approval)
    function depositWithPermit(
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyOwner {
        try
            IERC20Permit(token).permit(
                msg.sender,
                address(this),
                amount,
                deadline,
                v,
                r,
                s
            )
        {} catch {
            revert("Permit failed");
        }
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 valueInUSD = getValueInUSD(token, amount);
        uint8 tokenDecimals = IERC20Metadata(token).decimals();

        IERC20(token).forceApprove(address(aavePool), amount);
        aavePool.supply(token, amount, address(this), REFERRAL_CODE);

        (, , , , , uint256 healthFactor) = aavePool.getUserAccountData(
            address(this)
        );

        emit Deposited(
            msg.sender,
            token,
            amount,
            valueInUSD,
            healthFactor,
            tokenDecimals
        );
    }

    /// @notice Execute one leverage loop step: Borrow -> Swap -> Supply
    /// @dev Called by Reactive Network via Callback Proxy
    /// @param sender ReactVM ID (injected by Reactive Network for auth)
    /// @param borrowAsset Token to borrow (USDC/USDT/DAI)
    /// @param collateralAsset Token to buy and supply (WETH)
    /// @param amountToBorrow Amount to borrow (in borrowAsset's native decimals)
    /// @param iterationId Loop iteration counter
    function executeLeverageStep(
        address sender,
        address borrowAsset,
        address collateralAsset,
        uint256 amountToBorrow,
        uint256 /* amountOutMin */,
        uint256 iterationId
    ) external nonReentrant onlyController(sender) {
        // 1. Borrow from Aave
        aavePool.borrow(
            borrowAsset,
            amountToBorrow,
            VARIABLE_INTEREST_RATE_MODE,
            REFERRAL_CODE,
            address(this)
        );

        // 2. Calculate minimum output using Aave oracle prices
        uint256 minAmountOut = calculateMinOutput(
            borrowAsset,
            collateralAsset,
            amountToBorrow
        );

        // 3. Swap using Uniswap V3
        IERC20(borrowAsset).forceApprove(address(swapRouter), amountToBorrow);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: borrowAsset,
                tokenOut: collateralAsset,
                fee: defaultPoolFee,
                recipient: address(this),
                amountIn: amountToBorrow,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: 0
            });

        uint256 received = swapRouter.exactInputSingle(params);

        // 4. Supply received collateral to Aave
        IERC20(collateralAsset).forceApprove(address(aavePool), received);
        aavePool.supply(
            collateralAsset,
            received,
            address(this),
            REFERRAL_CODE
        );

        // 5. Calculate USD value of new collateral
        uint256 newCollateralValueUSD = getValueInUSD(
            collateralAsset,
            received
        );

        uint8 borrowAssetDecimals = IERC20Metadata(borrowAsset).decimals();

        (, , , , , uint256 healthFactor) = aavePool.getUserAccountData(
            address(this)
        );

        emit LoopStepExecuted(
            amountToBorrow,
            received,
            newCollateralValueUSD,
            healthFactor,
            iterationId,
            borrowAssetDecimals
        );
    }

    /// @notice Close position: repay all debt and withdraw collateral
    function fullClosePosition(
        address collateralAsset,
        address debtAsset,
        uint256 repayAmount
    ) external onlyOwner {
        IERC20(debtAsset).safeTransferFrom(
            msg.sender,
            address(this),
            repayAmount
        );

        IERC20(debtAsset).forceApprove(address(aavePool), repayAmount);
        uint256 repaid = aavePool.repay(
            debtAsset,
            type(uint256).max,
            VARIABLE_INTEREST_RATE_MODE,
            address(this)
        );

        uint256 withdrawn = aavePool.withdraw(
            collateralAsset,
            type(uint256).max,
            msg.sender
        );

        uint256 excess = IERC20(debtAsset).balanceOf(address(this));
        if (excess > 0) {
            IERC20(debtAsset).safeTransfer(msg.sender, excess);
        }

        (, , , , , uint256 healthFactor) = aavePool.getUserAccountData(
            address(this)
        );

        emit PositionClosed(repaid, withdrawn, healthFactor);
    }

    /// @notice Partial debt repayment
    function repayPartial(
        address debtAsset,
        uint256 amount
    ) external onlyOwner {
        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(debtAsset).forceApprove(address(aavePool), amount);

        aavePool.repay(
            debtAsset,
            amount,
            VARIABLE_INTEREST_RATE_MODE,
            address(this)
        );
    }

    /// @notice Returns the owner address as the rescue recipient
    function _rescueRecipient() internal view override returns (address) {
        return owner();
    }

    function rescueETH(uint256 amount) external override onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        _rescueETH(amount);
    }

    function rescueAllETH() external override onlyOwner {
        _rescueETH(0);
    }

    function rescueERC20(
        address token,
        uint256 amount
    ) external override onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        _rescueERC20(token, amount);
    }

    function rescueAllERC20(address token) external override onlyOwner {
        _rescueERC20(token, 0);
    }

    /// @notice Get current position status from Aave
    function getStatus()
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return aavePool.getUserAccountData(address(this));
    }

    /// @notice Get asset price with error handling (non-reverting)
    function tryGetAssetPrice(
        address asset
    ) external view returns (bool success, uint256 price) {
        try this.getAssetPrice(asset) returns (uint256 p) {
            return (true, p);
        } catch {
            return (false, 0);
        }
    }
}
