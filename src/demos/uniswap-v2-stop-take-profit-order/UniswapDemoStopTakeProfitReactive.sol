// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import "../../../lib/reactive-lib/src/interfaces/IReactive.sol";
import "../../../lib/reactive-lib/src/abstract-base/AbstractReactive.sol";
import "../../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PersonalStopOrderReactive
 * @notice Personal reactive smart contract for monitoring stop orders
 * @dev Each user deploys their own instance paired with PersonalStopOrderCallback
 */
contract UniswapDemoStopTakeProfitReactive is IReactive, AbstractReactive {
    // Events
    event OrderTracked(address indexed pair, uint256 indexed orderId);

    event OrderUntracked(address indexed pair, uint256 indexed orderId);

    event PairSubscribed(address indexed pair);

    event PairUnsubscribed(address indexed pair);

    event ExecutionTriggered(uint256 indexed orderId, address indexed pair, bool priceConditionMet);

    event ProcessingError(string reason, uint256 orderId);

    event ThresholdCheck(
        uint256 indexed orderId, uint256 calculated, uint256 threshold, bool conditionMet, bool sellToken0
    );

    // Constants
    uint256 private constant SEPOLIA_CHAIN_ID = 1;
    uint256 private constant REACTIVE_CHAIN_ID = 1597; // Lasna network chain ID
    uint256 private constant UNISWAP_V2_SYNC_TOPIC_0 =
        0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1;
    uint256 private constant STOP_ORDER_CREATED_TOPIC_0 =
        0xc617c0f87fe14fdefff1476f1b4c2c15c9492ea39a9c2e19d4401bf09fbb06a8; // keccak256("StopOrderCreated(address,uint256,bool,address,address,uint256,uint256,uint256,uint8)")
    uint256 private constant STOP_ORDER_CANCELLED_TOPIC_0 =
        0xad9e9b6169c70ec1a50cf90107a9621b005376a3aa8662130d414a541693149d; // keccak256("StopOrderCancelled(uint256)")
    uint256 private constant STOP_ORDER_EXECUTED_TOPIC_0 =
        0x90979f4e8ed6baf430ca253822dfbd281b8d2c27d7a5121b484b4bfcaca4297f; // keccak256("StopOrderExecuted(address,uint256,address,address,uint256,uint256)")
    uint256 private constant STOP_ORDER_PAUSED_TOPIC_0 =
        0x7c070b2e9334d802a093c6b4a80f124bf4ffc8a9af89d0dae72ab22309f96889; // keccak256("StopOrderPaused(uint256)")
    uint256 private constant STOP_ORDER_RESUMED_TOPIC_0 =
        0x310f8f7e10ddae556ab6ef7c362667de2c95fad69956c224c16aa058755669a7; // keccak256("StopOrderResumed(uint256)")
    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    enum OrderType {
        StopLoss,
        TakeProfit
    }

    // Order status enum (mirrors the callback contract)
    enum OrderStatus {
        Active,
        Paused,
        Cancelled,
        Executed,
        Failed
    }

    // Reserves struct for Uniswap sync events
    struct Reserves {
        uint112 reserve0;
        uint112 reserve1;
    }

    // Order tracking struct
    struct TrackedOrder {
        uint256 id;
        address pair;
        bool sellToken0;
        uint256 coefficient;
        uint256 threshold;
        OrderType orderType;
        OrderStatus status;
        uint256 lastTriggeredAt;
        uint8 triggerCount;
    }

    // State variables
    address public immutable owner;
    address public immutable stopOrderCallback;

    // Order tracking
    mapping(uint256 => TrackedOrder) public trackedOrders;
    mapping(address => uint256[]) public pairOrders; // pair -> orderIds
    mapping(address => uint256) public pairOrderCount;
    mapping(address => bool) public subscribedPairs;

    // Constants for retry logic
    uint256 private constant TRIGGER_COOLDOWN = 300; // 5 minutes between triggers
    uint8 private constant MAX_TRIGGER_ATTEMPTS = 5;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    constructor(address _owner, address _stopOrderCallback) payable {
        owner = _owner;
        stopOrderCallback = _stopOrderCallback;

        if (!vm) {
            // Subscribe to stop order lifecycle events from the personal callback contract
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                stopOrderCallback,
                STOP_ORDER_CREATED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            service.subscribe(
                SEPOLIA_CHAIN_ID,
                stopOrderCallback,
                STOP_ORDER_CANCELLED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            service.subscribe(
                SEPOLIA_CHAIN_ID,
                stopOrderCallback,
                STOP_ORDER_EXECUTED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            service.subscribe(
                SEPOLIA_CHAIN_ID,
                stopOrderCallback,
                STOP_ORDER_PAUSED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            service.subscribe(
                SEPOLIA_CHAIN_ID,
                stopOrderCallback,
                STOP_ORDER_RESUMED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    // Main reaction function
    function react(LogRecord calldata log) external vmOnly {
        if (log._contract == stopOrderCallback) {
            _processStopOrderEvent(log);
        } else if (log.topic_0 == UNISWAP_V2_SYNC_TOPIC_0 && subscribedPairs[log._contract]) {
            _processSyncEvent(log);
        }
    }

    // Process stop order lifecycle events
    function _processStopOrderEvent(LogRecord calldata log) internal {
        if (log.topic_0 == STOP_ORDER_CREATED_TOPIC_0) {
            _processOrderCreated(log);
        } else if (log.topic_0 == STOP_ORDER_CANCELLED_TOPIC_0) {
            _processOrderCancelled(log);
        } else if (log.topic_0 == STOP_ORDER_EXECUTED_TOPIC_0) {
            _processOrderExecuted(log);
        } else if (log.topic_0 == STOP_ORDER_PAUSED_TOPIC_0) {
            _processOrderPaused(log);
        } else if (log.topic_0 == STOP_ORDER_RESUMED_TOPIC_0) {
            _processOrderResumed(log);
        }
    }

    // Process order creation
    function _processOrderCreated(LogRecord calldata log) internal {
        // Extract data from event topics
        address pair = address(uint160(log.topic_1));
        uint256 orderId = uint256(log.topic_2);

        // Decode additional data from log.data
        (bool sellToken0,,,, uint256 coefficient, uint256 threshold, OrderType orderType) =
            abi.decode(log.data, (bool, address, address, uint256, uint256, uint256, OrderType));

        // Track the order
        trackedOrders[orderId] = TrackedOrder({
            id: orderId,
            pair: pair,
            sellToken0: sellToken0,
            coefficient: coefficient,
            threshold: threshold,
            orderType: orderType,
            status: OrderStatus.Active,
            lastTriggeredAt: 0,
            triggerCount: 0
        });

        // Add to pair's order list
        pairOrders[pair].push(orderId);

        // Subscribe to pair if this is the first order
        if (pairOrderCount[pair] == 0) {
            _requestPairSubscription(pair, log.chain_id);
        }

        pairOrderCount[pair]++;

        emit OrderTracked(pair, orderId);
    }

    // Process order cancellation
    function _processOrderCancelled(LogRecord calldata log) internal {
        uint256 orderId = uint256(log.topic_1);

        if (trackedOrders[orderId].id == orderId) {
            address pair = trackedOrders[orderId].pair;
            trackedOrders[orderId].status = OrderStatus.Cancelled;

            _decrementPairCount(pair);

            emit OrderUntracked(pair, orderId);
        }
    }

    // Process order execution
    function _processOrderExecuted(LogRecord calldata log) internal {
        uint256 orderId = uint256(log.topic_2);

        if (trackedOrders[orderId].id == orderId) {
            address pair = trackedOrders[orderId].pair;
            trackedOrders[orderId].status = OrderStatus.Executed;

            _decrementPairCount(pair);

            emit OrderUntracked(pair, orderId);
        }
    }

    // Process order pause
    function _processOrderPaused(LogRecord calldata log) internal {
        uint256 orderId = uint256(log.topic_1);

        if (trackedOrders[orderId].id == orderId) {
            trackedOrders[orderId].status = OrderStatus.Paused;
        }
    }

    // Process order resume
    function _processOrderResumed(LogRecord calldata log) internal {
        uint256 orderId = uint256(log.topic_1);

        if (trackedOrders[orderId].id == orderId) {
            trackedOrders[orderId].status = OrderStatus.Active;
        }
    }

    // Process Uniswap sync events - Core monitoring logic
    function _processSyncEvent(LogRecord calldata log) internal {
        address pair = log._contract;
        Reserves memory reserves = abi.decode(log.data, (Reserves));

        // Get all orders for this pair
        uint256[] storage orderIds = pairOrders[pair];

        for (uint256 i = 0; i < orderIds.length; i++) {
            uint256 orderId = orderIds[i];
            TrackedOrder storage order = trackedOrders[orderId];

            // Skip non-active orders
            if (order.status != OrderStatus.Active) {
                continue;
            }

            // Check trigger cooldown
            if (order.lastTriggeredAt > 0 && block.timestamp < order.lastTriggeredAt + TRIGGER_COOLDOWN) {
                continue;
            }

            // Check max trigger attempts
            if (order.triggerCount >= MAX_TRIGGER_ATTEMPTS) {
                order.status = OrderStatus.Failed;
                emit ProcessingError("Max retries exceeded", orderId);
                continue;
            }

            // Check if price condition is met
            bool shouldTrigger =
                _isPriceConditionMet(order.sellToken0, reserves, order.coefficient, order.threshold, order.orderType);

            // Emit detailed debug event
            uint256 calculated;
            if (order.sellToken0) {
                calculated = Math.mulDiv(uint256(reserves.reserve1), order.coefficient, uint256(reserves.reserve0));
            } else {
                calculated = Math.mulDiv(uint256(reserves.reserve0), order.coefficient, uint256(reserves.reserve1));
            }

            emit ThresholdCheck(orderId, calculated, order.threshold, shouldTrigger, order.sellToken0);

            if (shouldTrigger) {
                _triggerExecution(orderId, pair);
            }
        }
    }

    // Check if price condition is met based on order type
    function _isPriceConditionMet(
        bool sellToken0,
        Reserves memory reserves,
        uint256 coefficient,
        uint256 threshold,
        OrderType orderType // ADD THIS PARAMETER
    ) internal pure returns (bool) {
        uint256 currentPrice;

        if (sellToken0) {
            // Price of token0 in terms of token1
            currentPrice = Math.mulDiv(uint256(reserves.reserve1), coefficient, uint256(reserves.reserve0));
        } else {
            // Price of token1 in terms of token0
            currentPrice = Math.mulDiv(uint256(reserves.reserve0), coefficient, uint256(reserves.reserve1));
        }

        if (orderType == OrderType.StopLoss) {
            return currentPrice <= threshold; // Execute when price drops below threshold
        } else {
            return currentPrice >= threshold; // Execute when price rises above threshold
        }
    }

    // Trigger order execution
    function _triggerExecution(uint256 orderId, address pair) internal {
        TrackedOrder storage order = trackedOrders[orderId];

        // Update trigger tracking
        order.lastTriggeredAt = block.timestamp;
        order.triggerCount++;

        // Create callback payload
        bytes memory payload = abi.encodeWithSignature(
            "executeStopOrder(address,uint256)",
            address(0), // sender is ignored in callback
            orderId
        );

        // Emit callback to Sepolia chain
        emit Callback(SEPOLIA_CHAIN_ID, stopOrderCallback, CALLBACK_GAS_LIMIT, payload);

        emit ExecutionTriggered(orderId, pair, true);
    }

    // Request pair subscription using callback mechanism
    function _requestPairSubscription(address pair, uint256 chainId) internal {
        if (!subscribedPairs[pair]) {
            // Create a callback to subscribe on the Reactive Network
            bytes memory payload =
                abi.encodeWithSignature("subscribeToPair(address,address,uint256)", address(0), pair, chainId);

            // Emit callback to Reactive Network to handle the subscription
            emit Callback(REACTIVE_CHAIN_ID, address(this), CALLBACK_GAS_LIMIT, payload);

            // Mark as requested
            subscribedPairs[pair] = true;
            emit PairSubscribed(pair);
        }
    }

    // Request pair unsubscription using callback mechanism
    function _requestPairUnsubscription(address pair, uint256 chainId) internal {
        if (subscribedPairs[pair]) {
            // Create a callback to unsubscribe on the Reactive Network
            bytes memory payload =
                abi.encodeWithSignature("unsubscribeFromPair(address,address,uint256)", address(0), pair, chainId);

            // Emit callback to Reactive Network to handle the unsubscription
            emit Callback(REACTIVE_CHAIN_ID, address(this), CALLBACK_GAS_LIMIT, payload);

            // Mark as requested
            subscribedPairs[pair] = false;
            emit PairUnsubscribed(pair);
        }
    }

    // Methods for Reactive Network to execute subscription (via callback)
    function subscribeToPair(
        address,
        /*sender*/
        address pair,
        uint256 chainId
    )
        external
        rnOnly
    {
        // Execute the subscription
        service.subscribe(chainId, pair, UNISWAP_V2_SYNC_TOPIC_0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    // Methods for Reactive Network to execute unsubscription (via callback)
    function unsubscribeFromPair(
        address,
        /*sender*/
        address pair,
        uint256 chainId
    )
        external
        rnOnly
    {
        // Execute the unsubscription
        service.unsubscribe(chainId, pair, UNISWAP_V2_SYNC_TOPIC_0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    // Decrement pair order count and unsubscribe if needed
    function _decrementPairCount(address pair) internal {
        if (pairOrderCount[pair] > 0) {
            pairOrderCount[pair]--;

            // Unsubscribe if no more active orders
            if (pairOrderCount[pair] == 0) {
                _requestPairUnsubscription(pair, SEPOLIA_CHAIN_ID);
            }
        }
    }

    // Emergency function to manually force subscription (owner only)
    function emergencySubscribeToPair(address pair, uint256 chainId) external onlyOwner {
        service.subscribe(chainId, pair, UNISWAP_V2_SYNC_TOPIC_0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
        subscribedPairs[pair] = true;
        emit PairSubscribed(pair);
    }

    // Emergency function to manually force unsubscription (owner only)
    function emergencyUnsubscribeFromPair(address pair, uint256 chainId) external onlyOwner {
        service.unsubscribe(chainId, pair, UNISWAP_V2_SYNC_TOPIC_0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
        subscribedPairs[pair] = false;
        emit PairUnsubscribed(pair);
    }

    function getActiveOrdersForPair(address pair) external view returns (uint256[] memory) {
        uint256[] storage allOrders = pairOrders[pair];
        uint256 activeCount = 0;

        // Count active orders
        for (uint256 i = 0; i < allOrders.length; i++) {
            if (trackedOrders[allOrders[i]].status == OrderStatus.Active) {
                activeCount++;
            }
        }

        // Build active orders array
        uint256[] memory activeOrders = new uint256[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < allOrders.length; i++) {
            if (trackedOrders[allOrders[i]].status == OrderStatus.Active) {
                activeOrders[index] = allOrders[i];
                index++;
            }
        }

        return activeOrders;
    }

    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient address");
        SafeERC20.safeTransfer(IERC20(token), to, amount);
    }

    function rescueAllERC20(address token, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to rescue");
        SafeERC20.safeTransfer(IERC20(token), to, balance);
    }

    // Emergency withdrawal functions - only deployer can call
    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient ETH balance");

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function withdrawAllETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");

        (bool success,) = payable(msg.sender).call{value: balance}("");
        require(success, "ETH transfer failed");
    }
}
