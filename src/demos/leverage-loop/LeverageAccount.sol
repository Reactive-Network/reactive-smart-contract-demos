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

    /* 
    /// TO BE IMPLEMENTED IN STAGE 2: Oracle and Price Helpers
    function setOracle(...)
    function setOraclesBatch(...)
    function setSlippageTolerance(...)
    function setPoolFee(...)
    function getAssetPrice(...)
    function getValueInUSD(...)
    function calculateMinOutput(...)
    function setRSCCaller(...)

    /// TO BE IMPLEMENTED IN STAGE 3: Deposit Logic
    function deposit(...)
    function depositWithPermit(...)

    /// TO BE IMPLEMENTED IN STAGE 4: Leverage Logic
    function executeLeverageStep(...)

    /// TO BE IMPLEMENTED IN STAGE 5: Closing & Withdrawals
    function fullClosePosition(...)
    function repayPartial(...)
    function withdraw(...)
    function withdrawETH(...)
    function getStatus(...)
    function tryGetAssetPrice(...)
    */
}
