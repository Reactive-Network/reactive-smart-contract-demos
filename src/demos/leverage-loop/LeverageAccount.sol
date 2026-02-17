// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol";

/// @title Chainlink Aggregator Interface
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
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

/// @title Uniswap V3 SwapRouter Interface
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

/// @title LeverageAccount - User's leveraged position vault with Chainlink & Aave V3
/// @notice Receives callbacks from Reactive Network to execute leverage loops
contract LeverageAccount is AbstractCallback, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Protocol contracts
    IPool public aavePool;
    ISwapRouter public swapRouter;
    address public callbackProxy;

    // Oracle management
    mapping(address => address) public assetOracles; // asset => Chainlink aggregator
    uint256 public constant STALENESS_THRESHOLD = 3600; // 1 hour
    uint256 public constant PRICE_DECIMALS = 18; // Standardize all prices to 18 decimals

    // Swap configuration
    uint24 public defaultPoolFee = 3000; // 0.3% pool fee (most liquid)
    uint256 public slippageTolerance = 200; // 2% (in basis points)

    // Authorization
    address public rscCaller;

    // Aave constants
    uint256 private constant VARIABLE_INTEREST_RATE_MODE = 2;
    uint16 private constant REFERRAL_CODE = 0;

    // Events - Enhanced with USD values and decimals for RSC
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

    event OracleUpdated(address indexed asset, address indexed oracle);
    event SlippageConfigured(uint256 newTolerance);
    event PoolFeeUpdated(uint24 newFee);

    constructor(
        address _aavePool,
        address _swapRouter,
        address _callbackProxy,
        address _rscCaller
    ) payable AbstractCallback(_callbackProxy) Ownable(msg.sender) {
        require(_aavePool != address(0), "Invalid Aave pool");
        require(_swapRouter != address(0), "Invalid swap router");
        require(_callbackProxy != address(0), "Invalid callback proxy");
        aavePool = IPool(_aavePool);
        swapRouter = ISwapRouter(_swapRouter);
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

    /// @notice Set Chainlink oracle for an asset
    /// @param asset The token address (e.g., WETH, USDC)
    /// @param oracle The Chainlink aggregator address for asset/USD
    function setOracle(address asset, address oracle) external onlyOwner {
        require(asset != address(0) && oracle != address(0), "Invalid address");
        assetOracles[asset] = oracle;
        emit OracleUpdated(asset, oracle);
    }

    /// @notice Batch set oracles for multiple assets
    function setOraclesBatch(
        address[] calldata assets,
        address[] calldata oracles
    ) external onlyOwner {
        require(assets.length == oracles.length, "Length mismatch");
        for (uint256 i = 0; i < assets.length; i++) {
            require(
                assets[i] != address(0) && oracles[i] != address(0),
                "Invalid address"
            );
            assetOracles[assets[i]] = oracles[i];
            emit OracleUpdated(assets[i], oracles[i]);
        }
    }

    /// @notice Configure slippage tolerance
    /// @param _slippageBps Slippage in basis points (200 = 2%)
    function setSlippageTolerance(uint256 _slippageBps) external onlyOwner {
        require(_slippageBps <= 1000, "Slippage too high"); // Max 10%
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

    /// @notice Get real-time asset price in USD with 18 decimal precision
    /// @dev Handles Chainlink's 8-decimal format and performs staleness checks
    /// @param asset The token address
    /// @return price The asset price in USD (18 decimals)
    function getAssetPrice(address asset) public view returns (uint256 price) {
        address oracle = assetOracles[asset];
        require(oracle != address(0), "Oracle not set");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(oracle);

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        // Validation checks
        require(answer > 0, "Invalid price");
        require(answeredInRound >= roundId, "Stale round data");
        require(
            block.timestamp - updatedAt <= STALENESS_THRESHOLD,
            "Price data stale"
        );

        // Decimal conversion: Chainlink uses 8 decimals, we standardize to 18
        uint8 oracleDecimals = priceFeed.decimals();

        if (oracleDecimals < PRICE_DECIMALS) {
            // Scale up: e.g., 8 decimals -> 18 decimals (multiply by 10^10)
            price = uint256(answer) * (10 ** (PRICE_DECIMALS - oracleDecimals));
        } else if (oracleDecimals > PRICE_DECIMALS) {
            // Scale down: e.g., 20 decimals -> 18 decimals (divide by 10^2)
            price = uint256(answer) / (10 ** (oracleDecimals - PRICE_DECIMALS));
        } else {
            // Already 18 decimals
            price = uint256(answer);
        }
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

        // Formula: (amount * price) / 10^tokenDecimals
        // Result is in 18 decimals because price is 18 decimals
        valueUSD = (amount * price) / (10 ** tokenDecimals);
    }

    /// @notice Calculate minimum output for a swap with slippage protection
    /// @dev Uses REAL-TIME oracle prices at execution
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param amountIn Input amount
    /// @return minAmountOut Minimum acceptable output (with slippage)
    function calculateMinOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256 minAmountOut) {
        // Get current prices from Chainlink
        uint256 priceIn = getAssetPrice(tokenIn); // 18 decimals
        uint256 priceOut = getAssetPrice(tokenOut); // 18 decimals

        uint8 decimalsIn = IERC20Metadata(tokenIn).decimals();
        uint8 decimalsOut = IERC20Metadata(tokenOut).decimals();

        // Calculate expected output in tokenOut's native decimals
        // expectedOut = (amountIn * priceIn / priceOut) * (10^decimalsOut / 10^decimalsIn)
        uint256 expectedOut = (amountIn * priceIn * (10 ** decimalsOut)) /
            (priceOut * (10 ** decimalsIn));

        // Apply slippage tolerance
        minAmountOut = (expectedOut * (10000 - slippageTolerance)) / 10000;
    }

    /// @notice Update RSC caller address
    function setRSCCaller(address _rscCaller) external onlyOwner {
        rscCaller = _rscCaller;
    }

    /// @notice Deposit collateral with USD value calculation
    /// @param token The collateral token (e.g., WETH)
    /// @param amount The amount to deposit
    function deposit(address token, uint256 amount) external onlyOwner {
        // Transfer tokens from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Calculate USD value using Chainlink oracle
        uint256 valueInUSD = getValueInUSD(token, amount);
        uint8 tokenDecimals = IERC20Metadata(token).decimals();

        // Approve Aave pool (forceApprove handles USDT-like tokens)
        IERC20(token).forceApprove(address(aavePool), amount);

        // Supply to Aave V3
        aavePool.supply(token, amount, address(this), REFERRAL_CODE);

        // Get health factor from Aave
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
        // Execute permit
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
        // Transfer tokens
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Calculate USD value
        uint256 valueInUSD = getValueInUSD(token, amount);
        uint8 tokenDecimals = IERC20Metadata(token).decimals();

        // Approve and supply to Aave
        IERC20(token).forceApprove(address(aavePool), amount);
        aavePool.supply(token, amount, address(this), REFERRAL_CODE);

        // Get health factor
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
    /// @dev Slippage protection calculated dynamically using REAL-TIME oracles
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

        // 2. Calculate minimum output using REAL-TIME oracles
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
                deadline: block.timestamp + 300,
                amountIn: amountToBorrow,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: 0 // No price limit
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

        // Get borrow asset decimals for RSC (fixes Problem C)
        uint8 borrowAssetDecimals = IERC20Metadata(borrowAsset).decimals();

        // Get updated health factor from Aave
        (, , , , , uint256 healthFactor) = aavePool.getUserAccountData(
            address(this)
        );

        // Emit enhanced event with decimals info
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
    /// @param collateralAsset The collateral token (e.g., WETH)
    /// @param debtAsset The debt token (e.g., USDC)
    /// @param repayAmount Amount of debt tokens to pull from sender (in token's native decimals)
    function fullClosePosition(
        address collateralAsset,
        address debtAsset,
        uint256 repayAmount
    ) external onlyOwner {
        // Transfer debt tokens from owner
        IERC20(debtAsset).safeTransferFrom(
            msg.sender,
            address(this),
            repayAmount
        );

        // Repay all debt (type(uint256).max tells Aave to repay exact outstanding debt)
        IERC20(debtAsset).forceApprove(address(aavePool), repayAmount);
        uint256 repaid = aavePool.repay(
            debtAsset,
            type(uint256).max,
            VARIABLE_INTEREST_RATE_MODE,
            address(this)
        );

        // Withdraw all collateral to owner
        uint256 withdrawn = aavePool.withdraw(
            collateralAsset,
            type(uint256).max,
            msg.sender
        );

        // Refund excess debt tokens to owner
        uint256 excess = IERC20(debtAsset).balanceOf(address(this));
        if (excess > 0) {
            IERC20(debtAsset).safeTransfer(msg.sender, excess);
        }

        // Get final health factor
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

    /// @notice Emergency withdraw tokens from contract
    function withdraw(address token, uint256 amount) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /// @notice Withdraw ETH (for callback payment reserves)
    function withdrawETH(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH");
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "ETH transfer failed");
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
