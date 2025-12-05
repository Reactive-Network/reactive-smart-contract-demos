// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../../../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../../../lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./RescuableBase.sol";

/**
 * @title PersonalStopOrderCallback
 * @notice Personal stop order system for individual users
 * @dev Each user deploys their own instance for complete control and privacy
 */
contract UniswapDemoStopTakeProfitCallback is AbstractCallback, RescuableBase {
    using SafeERC20 for IERC20;

    // Events
    event StopOrderCreated(
        address indexed pair,
        uint256 indexed orderId,
        bool sellToken0,
        address tokenSell,
        address tokenBuy,
        uint256 amount,
        uint256 coefficient,
        uint256 threshold,
        OrderType orderType
    );

    event StopOrderExecuted(
        address indexed pair,
        uint256 indexed orderId,
        address tokenSell,
        address tokenBuy,
        uint256 amountIn,
        uint256 amountOut
    );

    event StopOrderCancelled(uint256 indexed orderId);
    event StopOrderPaused(uint256 indexed orderId);
    event StopOrderResumed(uint256 indexed orderId);

    error OrderNotActive(uint256 orderId);
    error PriceConditionNotMet(uint256 orderId);
    error MaxRetriesExceeded(uint256 orderId);
    error InsufficientBalanceOrAllowance(uint256 orderId);
    error SwapExecutionFailed(uint256 orderId);

    // Order status enum
    enum OrderStatus {
        Active,
        Paused,
        Cancelled,
        Executed,
        Failed
    }
    enum OrderType {
        StopLoss,
        TakeProfit
    }

    // Stop order struct
    struct StopOrder {
        uint256 id;
        address pair;
        address tokenSell;
        address tokenBuy;
        uint256 amount;
        bool sellToken0;
        uint256 coefficient;
        uint256 threshold;
        OrderType orderType; // ADD THIS LINE
        OrderStatus status;
        uint256 createdAt;
        uint256 executedAt;
        uint8 retryCount;
        uint256 lastExecutionAttempt;
    }

    // State variables
    address public immutable owner;
    IUniswapV2Router02 public immutable router;

    // mapping(uint256 => StopOrder) public stopOrders;
    // uint256[] public orderIds; // Track all order IDs for easy enumeration
    StopOrder[] public stopOrders;
    uint256 public nextOrderId;

    // Configuration
    uint256 private constant DEADLINE_OFFSET = 300; // 5 minutes
    uint8 private constant MAX_RETRIES = 3;
    uint256 private constant RETRY_COOLDOWN = 30; // 30 seconds
    uint256 private constant MIN_AMOUNT = 1000; // Minimum amount to prevent dust

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier validOrder(uint256 orderId) {
        require(orderId < stopOrders.length, "Order does not exist");
        _;
    }

    constructor(address _owner, address _callbackSender, address _router) payable AbstractCallback(_callbackSender) {
        owner = _owner;
        router = IUniswapV2Router02(_router);
    }

    /**
     * @notice Creates a new stop order (stop loss or take profit)
     * @param pair The Uniswap V2 pair address
     * @param sellToken0 Whether to sell token0 (true) or token1 (false)
     * @param amount Amount of tokens to sell
     * @param coefficient Price calculation coefficient
     * @param threshold Price threshold that triggers the order
     * @param orderType Type of order (StopLoss or TakeProfit)
     */
    function createStopOrder(
        address pair,
        bool sellToken0,
        uint256 amount,
        uint256 coefficient,
        uint256 threshold,
        OrderType orderType
    ) external onlyOwner returns (uint256) {
        require(pair != address(0), "Invalid pair address");
        require(amount >= MIN_AMOUNT, "Amount too small");
        require(coefficient > 0 && threshold > 0, "Invalid price parameters");

        // Get token addresses from pair
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        address tokenSell = sellToken0 ? token0 : token1;
        address tokenBuy = sellToken0 ? token1 : token0;

        // Verify user has sufficient balance
        require(IERC20(tokenSell).balanceOf(owner) >= amount, "Insufficient balance");

        // Verify user has approved sufficient amount
        require(IERC20(tokenSell).allowance(owner, address(this)) >= amount, "Insufficient allowance");

        // Verify the pair is valid and has liquidity
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "Pair has no liquidity");

        // Create the order
        uint256 orderId = nextOrderId;
        stopOrders.push(
            StopOrder({
                id: orderId,
                pair: pair,
                tokenSell: tokenSell,
                tokenBuy: tokenBuy,
                amount: amount,
                sellToken0: sellToken0,
                coefficient: coefficient,
                threshold: threshold,
                orderType: orderType,
                status: OrderStatus.Active,
                createdAt: block.timestamp,
                executedAt: 0,
                retryCount: 0,
                lastExecutionAttempt: 0
            })
        );

        nextOrderId++;

        emit StopOrderCreated(pair, orderId, sellToken0, tokenSell, tokenBuy, amount, coefficient, threshold, orderType);

        return orderId;
    }

    /**
     * @notice Executes a stop order (called by RSC)
     * @dev Includes an on-chain price check as a final safeguard before execution
     * @param orderId The ID of the order to execute
     */
    function executeStopOrder(
        address,
        /*sender*/
        uint256 orderId
    )
        external
        authorizedSenderOnly
        validOrder(orderId)
    {
        StopOrder storage order = stopOrders[orderId];

        // Check order status
        if (order.status != OrderStatus.Active) {
            revert OrderNotActive(orderId);
        }

        // Final on-chain price check
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(order.pair).getReserves();
        if (!_isPriceConditionMet(
                order.sellToken0, reserve0, reserve1, order.coefficient, order.threshold, order.orderType
            )) {
            revert PriceConditionNotMet(orderId);
        }

        // Check retry cooldown
        if (order.lastExecutionAttempt > 0 && block.timestamp < order.lastExecutionAttempt + RETRY_COOLDOWN) {
            return;
        }

        // Check max retries
        if (order.retryCount >= MAX_RETRIES) {
            order.status = OrderStatus.Failed;
            revert MaxRetriesExceeded(orderId);
        }

        // Update execution attempt
        order.lastExecutionAttempt = block.timestamp;
        order.retryCount++;

        // Check owner still has sufficient balance and allowance
        uint256 ownerBalance = IERC20(order.tokenSell).balanceOf(owner);
        uint256 ownerAllowance = IERC20(order.tokenSell).allowance(owner, address(this));

        uint256 executeAmount = order.amount;
        if (ownerBalance < executeAmount) {
            executeAmount = ownerBalance;
        }
        if (ownerAllowance < executeAmount) {
            executeAmount = ownerAllowance;
        }
        if (executeAmount < MIN_AMOUNT) {
            order.status = OrderStatus.Failed;
            revert InsufficientBalanceOrAllowance(orderId);
        }

        // Execute the swap (will revert on failure)
        (, uint256 amountOut) = _executeSwap(order, executeAmount);

        // If we reach here, swap was successful
        order.status = OrderStatus.Executed;
        order.executedAt = block.timestamp;

        emit StopOrderExecuted(order.pair, orderId, order.tokenSell, order.tokenBuy, executeAmount, amountOut);
    }

    /**
     * @notice Cancels a stop order
     * @param orderId The ID of the order to cancel
     */
    function cancelStopOrder(uint256 orderId) external onlyOwner validOrder(orderId) {
        StopOrder storage order = stopOrders[orderId];
        require(order.status == OrderStatus.Active || order.status == OrderStatus.Paused, "Cannot cancel order");

        order.status = OrderStatus.Cancelled;
        emit StopOrderCancelled(orderId);
    }

    /**
     * @notice Pauses a stop order
     * @param orderId The ID of the order to pause
     */
    function pauseStopOrder(uint256 orderId) external onlyOwner validOrder(orderId) {
        StopOrder storage order = stopOrders[orderId];
        require(order.status == OrderStatus.Active, "Order is not active");

        order.status = OrderStatus.Paused;
        emit StopOrderPaused(orderId);
    }

    /**
     * @notice Resumes a paused stop order
     * @param orderId The ID of the order to resume
     */
    function resumeStopOrder(uint256 orderId) external onlyOwner validOrder(orderId) {
        StopOrder storage order = stopOrders[orderId];
        require(order.status == OrderStatus.Paused, "Order is not paused");

        order.status = OrderStatus.Active;
        emit StopOrderResumed(orderId);
    }

    /**
     * @notice Gets all order IDs
     * @return Array of all order IDs
     */
    function getAllOrders() external view returns (uint256[] memory) {
        uint256[] memory allOrderIds = new uint256[](stopOrders.length);
        for (uint256 i = 0; i < stopOrders.length; i++) {
            allOrderIds[i] = i;
        }
        return allOrderIds;
    }

    /**
     * @notice Gets active order IDs
     * @return Array of active order IDs
     */
    function getActiveOrders() external view returns (uint256[] memory) {
        uint256 activeCount = 0;

        // Count active orders
        for (uint256 i = 0; i < stopOrders.length; i++) {
            if (stopOrders[i].status == OrderStatus.Active) {
                activeCount++;
            }
        }

        // Build active orders array
        uint256[] memory activeOrders = new uint256[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < stopOrders.length; i++) {
            if (stopOrders[i].status == OrderStatus.Active) {
                activeOrders[index] = i;
                index++;
            }
        }

        return activeOrders;
    }

    /**
     * @notice Internal quote function (copied from UniswapV2Library to avoid version conflicts)
     * @dev Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
     */
    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, "UniswapV2Library: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA; // No need for SafeMath in 0.8.20+
    }

    /**
     * @notice Gets current price ratio for a pair (for informational purposes only)
     * @param pair The pair address
     * @param sellToken0 Whether selling token0
     * @return The current price ratio
     */
    function getCurrentPrice(address pair, bool sellToken0) external view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "No liquidity");

        if (sellToken0) {
            return _quote(1, uint256(reserve0), uint256(reserve1));
        } else {
            return _quote(1, uint256(reserve1), uint256(reserve0));
        }
    }

    function _executeSwap(StopOrder memory order, uint256 amount) internal returns (bool success, uint256 amountOut) {
        IERC20 tokenSell = IERC20(order.tokenSell);
        IERC20 tokenBuy = IERC20(order.tokenBuy);

        // Transfer tokens from owner to contract (will revert on failure)
        tokenSell.safeTransferFrom(owner, address(this), amount);

        // Approve router (will revert on failure)
        tokenSell.forceApprove(address(router), amount);

        // Execute swap
        address[] memory path = new address[](2);
        path[0] = order.tokenSell;
        path[1] = order.tokenBuy;

        uint256[] memory amounts =
            router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp + DEADLINE_OFFSET);

        // Transfer received tokens to owner (will revert on failure)
        amountOut = amounts[1];
        tokenBuy.safeTransfer(owner, amountOut);

        return (true, amountOut);
    }

    function _isPriceConditionMet(
        bool sellToken0,
        uint112 reserve0,
        uint112 reserve1,
        uint256 coefficient,
        uint256 threshold,
        OrderType orderType
    ) internal pure returns (bool) {
        uint256 currentPrice;

        if (sellToken0) {
            // Price of token0 in terms of token1
            currentPrice = Math.mulDiv(uint256(reserve1), coefficient, uint256(reserve0));
        } else {
            // Price of token1 in terms of token0
            currentPrice = Math.mulDiv(uint256(reserve0), coefficient, uint256(reserve1));
        }

        if (orderType == OrderType.StopLoss) {
            return currentPrice <= threshold; // Execute when price drops below threshold
        } else {
            return currentPrice >= threshold; // Execute when price rises above threshold
        }
    }

    /**
     * @notice Returns the owner address as the rescue recipient
     */
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
