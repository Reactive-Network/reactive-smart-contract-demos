// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
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

/// @title LeverageAccount - User's leveraged position vault
/// @notice Receives callbacks from Reactive Network to execute leverage loops
contract LeverageAccount is AbstractCallback, Ownable {
    IMockLendingPool public lendingPool;
    IMockRouter public router;
    address public rscCaller;

    event Deposited(address indexed user, uint256 amount, uint256 currentLTV);
    event LoopStepExecuted(
        uint256 borrowed,
        uint256 newCollateral,
        uint256 currentLTV,
        uint256 iterationId
    );
    event PositionClosed(uint256 debtRepaid, uint256 collateralReturned);

    constructor(
        address _lendingPool,
        address _router,
        address _callbackProxy,
        address _rscCaller
    ) payable AbstractCallback(_callbackProxy) Ownable(msg.sender) {
        lendingPool = IMockLendingPool(_lendingPool);
        router = IMockRouter(_router);
        rscCaller = _rscCaller;
    }

    modifier onlyController(address sender) {
        require(sender == owner() || sender == rscCaller, "Not authorized");
        _;
    }

    function setRSCCaller(address _rscCaller) external onlyOwner {
        rscCaller = _rscCaller;
    }

    /// @notice Deposit collateral (requires prior approval)
    function deposit(address token, uint256 amount) external onlyOwner {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(address(lendingPool), amount);
        lendingPool.supply(token, amount);

        (, , uint256 ltv) = lendingPool.getUserAccountData(address(this));
        emit Deposited(msg.sender, amount, ltv);
    }

    /// @notice Deposit with EIP-2612 permit (no prior approval needed)
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
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(address(lendingPool), amount);
        lendingPool.supply(token, amount);

        (, , uint256 ltv) = lendingPool.getUserAccountData(address(this));
        emit Deposited(msg.sender, amount, ltv);
    }

    /// @notice Execute one leverage loop step: Borrow -> Swap -> Supply
    /// @dev Called by Reactive Network via Callback Proxy
    /// @param sender ReactVM ID (injected by Reactive Network for auth)
    /// @param borrowAsset Token to borrow (USDT)
    /// @param collateralAsset Token to buy and supply (WETH)
    /// @param amountToBorrow Amount to borrow
    /// @param amountOutMin Minimum swap output (slippage protection)
    /// @param iterationId Loop iteration counter
    function executeLeverageStep(
        address sender,
        address borrowAsset,
        address collateralAsset,
        uint256 amountToBorrow,
        uint256 amountOutMin,
        uint256 iterationId
    ) external onlyController(sender) {
        // 1. Borrow
        lendingPool.borrow(borrowAsset, amountToBorrow);

        // 2. Swap borrowed asset to collateral
        IERC20(borrowAsset).approve(address(router), amountToBorrow);
        address[] memory path = new address[](2);
        path[0] = borrowAsset;
        path[1] = collateralAsset;

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountToBorrow,
            amountOutMin,
            path,
            address(this),
            block.timestamp
        );

        // 3. Supply received collateral
        uint256 received = amounts[1];
        IERC20(collateralAsset).approve(address(lendingPool), received);
        lendingPool.supply(collateralAsset, received);

        (, , uint256 ltv) = lendingPool.getUserAccountData(address(this));
        emit LoopStepExecuted(amountToBorrow, received, ltv, iterationId);
    }

    /// @notice Close position: repay all debt and withdraw collateral
    /// @dev User must approve debtAsset transfer to cover the debt
    function fullClosePosition(
        address collateralAsset,
        address debtAsset
    ) external onlyOwner {
        uint256 debt = lendingPool.borrowings(address(this), debtAsset);
        uint256 collateral = lendingPool.supplies(
            address(this),
            collateralAsset
        );
        require(collateral > 0, "No collateral");

        if (debt > 0) {
            IERC20(debtAsset).transferFrom(msg.sender, address(this), debt);
            IERC20(debtAsset).approve(address(lendingPool), debt);
            lendingPool.repay(debtAsset, debt);
        }

        lendingPool.withdraw(collateralAsset, collateral);
        IERC20(collateralAsset).transfer(msg.sender, collateral);

        emit PositionClosed(debt, collateral);
    }

    /// @notice Partial debt repayment
    function repayPartial(
        address debtAsset,
        uint256 amount
    ) external onlyOwner {
        IERC20(debtAsset).transferFrom(msg.sender, address(this), amount);
        IERC20(debtAsset).approve(address(lendingPool), amount);
        lendingPool.repay(debtAsset, amount);
    }

    /// @notice Withdraw tokens from contract
    function withdraw(address token, uint256 amount) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance >= amount) {
            IERC20(token).transfer(msg.sender, amount);
        }
    }

    /// @notice Withdraw ETH (for callback payment reserves)
    function withdrawETH(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH");
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    /// @notice Get current position status
    function getStatus()
        external
        view
        returns (uint256 collateral, uint256 debt, uint256 ltv)
    {
        return lendingPool.getUserAccountData(address(this));
    }
}
