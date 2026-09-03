// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import "../../../lib/reactive-lib/src/interfaces/IReactive.sol";
import "../../../lib/reactive-lib/src/abstract-base/AbstractReactive.sol";
import "../../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UniswapV2ILProtectionReactive
 * @notice Reactive Smart Contract that monitors Uniswap V2 reserve ratios and
 *         triggers automatic LP exit when impermanent loss divergence exceeds
 *         a user-defined threshold.
 *
 * @dev Architecture mirrors UniswapDemoStopTakeProfitReactive:
 *      - Subscribes to lifecycle events from the callback contract on Sepolia
 *        (PositionRegistered, PositionCancelled, PositionExited, PositionPaused, PositionResumed)
 *      - Dynamically subscribes/unsubscribes to Uniswap V2 Sync events per pair
 *        as positions are created/completed, optimising gas usage
 *      - On each Sync event, computes reserve-ratio divergence for all active
 *        positions on that pair and emits a Callback when threshold is breached
 */
contract UniswapV2ILProtectionReactive is IReactive, AbstractReactive {
    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event PositionTracked(address indexed pair, uint256 indexed positionId);
    event PositionUntracked(address indexed pair, uint256 indexed positionId);
    event PairSubscribed(address indexed pair);
    event PairUnsubscribed(address indexed pair);
    event ExitTriggered(uint256 indexed positionId, address indexed pair, uint256 divergenceBps);
    event DivergenceCheck(uint256 indexed positionId, uint256 divergenceBps, uint256 thresholdBps, bool breached);
    event ProcessingError(string reason, uint256 positionId);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant REACTIVE_CHAIN_ID = 5318007; // Lasna

    uint256 private constant UNISWAP_V2_SYNC_TOPIC_0 =
        0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1;

    // keccak256("PositionRegistered(address,uint256,address,address,uint256,uint256,uint256,uint256)")
    uint256 private constant POSITION_REGISTERED_TOPIC_0 =
        0xdd129c09b9db451b951d4a512b71eaa52015058f8b98f2fa0e0a84aca741f642;

    // keccak256("PositionExited(address,uint256,uint256,uint256,uint256)")
    uint256 private constant POSITION_EXITED_TOPIC_0 =
        0x648799a274c82ae910ac2fa0718b470b090b891fabe329a8549c227568cd819b;

    // keccak256("PositionCancelled(uint256)")
    uint256 private constant POSITION_CANCELLED_TOPIC_0 =
        0xee53664e9f50aa90922dc3cdd811255c96b0497e3074ad02ca9f85ef609d9ad4;

    // keccak256("PositionPaused(uint256)")
    uint256 private constant POSITION_PAUSED_TOPIC_0 =
        0xc5702b7aef5fbef2820bd55545be04870ae89b40e5a3437f2fc5cf4c33ce4d84;

    // keccak256("PositionResumed(uint256)")
    uint256 private constant POSITION_RESUMED_TOPIC_0 =
        0xc8c92c81828cbde368dcf01f4cb37dfa0b47af2309357ba1d874af84bf2bf2db;

    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;
    uint256 private constant BPS_DENOMINATOR = 10000;

    // Cooldown between repeated triggers for the same position (prevent spam)
    uint256 private constant TRIGGER_COOLDOWN = 300; // 5 minutes
    uint8 private constant MAX_TRIGGER_COUNT = 5;

    // -------------------------------------------------------------------------
    // Types
    // -------------------------------------------------------------------------

    enum PositionStatus {
        Active,
        Paused,
        Cancelled,
        Exited
    }

    /**
     * @notice Mirrors the LP position state needed for on-chain divergence checks
     * @dev Entry reserves are stored here so react() can evaluate divergence
     *      without a cross-chain call to Sepolia.
     */
    struct TrackedPosition {
        uint256 id;
        address pair;
        uint256 entryReserve0;
        uint256 entryReserve1;
        uint256 divergenceThresholdBps;
        PositionStatus status;
        uint256 lastTriggeredAt;
        uint8 triggerCount;
    }

    // Inline struct to decode Sync event log data (reserve0, reserve1 as uint112)
    struct Reserves {
        uint112 reserve0;
        uint112 reserve1;
    }

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    address public immutable owner;
    address public immutable ilProtectionCallback;

    // positionId => TrackedPosition
    mapping(uint256 => TrackedPosition) public trackedPositions;

    // pair => positionIds registered on that pair
    mapping(address => uint256[]) public pairPositions;

    // pair => count of active/monitored positions (drives subscribe/unsubscribe)
    mapping(address => uint256) public pairActiveCount;

    // pair => whether we are currently subscribed to its Sync events
    mapping(address => bool) public subscribedPairs;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _owner, address _ilProtectionCallback) payable {
        owner = _owner;
        ilProtectionCallback = _ilProtectionCallback;

        if (!vm) {
            // Subscribe to all position lifecycle events from the callback contract
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                ilProtectionCallback,
                POSITION_REGISTERED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                ilProtectionCallback,
                POSITION_EXITED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                ilProtectionCallback,
                POSITION_CANCELLED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                ilProtectionCallback,
                POSITION_PAUSED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                ilProtectionCallback,
                POSITION_RESUMED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    // -------------------------------------------------------------------------
    // IReactive: main entry point
    // -------------------------------------------------------------------------

    /**
     * @notice Called by the Reactive Network for every subscribed log event
     * @dev Routes to position lifecycle handlers or Sync event handler
     */
    function react(LogRecord calldata log) external vmOnly {
        if (log._contract == ilProtectionCallback) {
            _processPositionEvent(log);
        } else if (log.topic_0 == UNISWAP_V2_SYNC_TOPIC_0 && subscribedPairs[log._contract]) {
            _processSyncEvent(log);
        }
    }

    // -------------------------------------------------------------------------
    // Position lifecycle handlers
    // -------------------------------------------------------------------------

    function _processPositionEvent(LogRecord calldata log) internal {
        if (log.topic_0 == POSITION_REGISTERED_TOPIC_0) _processPositionRegistered(log);
        else if (log.topic_0 == POSITION_EXITED_TOPIC_0) _processPositionExited(log);
        else if (log.topic_0 == POSITION_CANCELLED_TOPIC_0) _processPositionCancelled(log);
        else if (log.topic_0 == POSITION_PAUSED_TOPIC_0) _processPositionPaused(log);
        else if (log.topic_0 == POSITION_RESUMED_TOPIC_0) _processPositionResumed(log);
    }

    /**
     * @dev PositionRegistered(address indexed pair, uint256 indexed positionId,
     *                          address token0, address token1,
     *                          uint256 lpAmount, uint256 entryReserve0,
     *                          uint256 entryReserve1, uint256 divergenceThresholdBps)
     *      topic_1 = pair, topic_2 = positionId
     *      data    = abi.encode(token0, token1, lpAmount, entryReserve0, entryReserve1, divergenceThresholdBps)
     */
    function _processPositionRegistered(LogRecord calldata log) internal {
        address pair = address(uint160(log.topic_1));
        uint256 positionId = uint256(log.topic_2);

        (
            , // token0
            , // token1
            , // lpAmount
            uint256 entryReserve0,
            uint256 entryReserve1,
            uint256 divergenceThresholdBps
        ) = abi.decode(log.data, (address, address, uint256, uint256, uint256, uint256));

        trackedPositions[positionId] = TrackedPosition({
            id: positionId,
            pair: pair,
            entryReserve0: entryReserve0,
            entryReserve1: entryReserve1,
            divergenceThresholdBps: divergenceThresholdBps,
            status: PositionStatus.Active,
            lastTriggeredAt: 0,
            triggerCount: 0
        });

        pairPositions[pair].push(positionId);

        // Subscribe to pair's Sync events on first active position
        if (pairActiveCount[pair] == 0) {
            _subscribeToPair(pair, log.chain_id);
        }
        pairActiveCount[pair]++;

        emit PositionTracked(pair, positionId);
    }

    /**
     * @dev PositionExited(address indexed pair, uint256 indexed positionId, ...)
     *      topic_1 = pair, topic_2 = positionId
     */
    function _processPositionExited(LogRecord calldata log) internal {
        uint256 positionId = uint256(log.topic_2);
        _deactivatePosition(positionId);
    }

    /**
     * @dev PositionCancelled(uint256 indexed positionId)
     *      topic_1 = positionId
     */
    function _processPositionCancelled(LogRecord calldata log) internal {
        uint256 positionId = uint256(log.topic_1);
        _deactivatePosition(positionId);
    }

    /**
     * @dev PositionPaused(uint256 indexed positionId)
     *      topic_1 = positionId
     */
    function _processPositionPaused(LogRecord calldata log) internal {
        uint256 positionId = uint256(log.topic_1);
        if (trackedPositions[positionId].id == positionId) {
            trackedPositions[positionId].status = PositionStatus.Paused;
        }
    }

    /**
     * @dev PositionResumed(uint256 indexed positionId)
     *      topic_1 = positionId
     */
    function _processPositionResumed(LogRecord calldata log) internal {
        uint256 positionId = uint256(log.topic_1);
        if (trackedPositions[positionId].id == positionId) {
            trackedPositions[positionId].status = PositionStatus.Active;
        }
    }

    // -------------------------------------------------------------------------
    // Sync event handler — core IL monitoring logic
    // -------------------------------------------------------------------------

    /**
     * @notice Processes a Uniswap V2 Sync event for a subscribed pair.
     *         Iterates all registered positions for that pair and checks
     *         whether reserve-ratio divergence from entry snapshot has
     *         exceeded each position's threshold.
     *
     * @dev Sync event data is abi-encoded as (uint112 reserve0, uint112 reserve1).
     *      We mirror the same cross-multiply divergence formula used in the callback
     *      contract so both layers agree on the trigger condition.
     */
    function _processSyncEvent(LogRecord calldata log) internal {
        address pair = log._contract;
        Reserves memory res = abi.decode(log.data, (Reserves));

        uint256[] storage positionIds = pairPositions[pair];

        for (uint256 i = 0; i < positionIds.length; i++) {
            uint256 positionId = positionIds[i];
            TrackedPosition storage pos = trackedPositions[positionId];

            // Only process active positions
            if (pos.status != PositionStatus.Active) continue;

            // Respect trigger cooldown
            if (pos.lastTriggeredAt > 0 && block.timestamp < pos.lastTriggeredAt + TRIGGER_COOLDOWN) continue;

            // Cap trigger attempts
            if (pos.triggerCount >= MAX_TRIGGER_COUNT) {
                pos.status = PositionStatus.Cancelled;
                emit ProcessingError("Max trigger attempts reached", positionId);
                continue;
            }

            // Compute divergence
            uint256 divergenceBps = _computeDivergenceBps(
                pos.entryReserve0, pos.entryReserve1, uint256(res.reserve0), uint256(res.reserve1)
            );

            bool breached = divergenceBps >= pos.divergenceThresholdBps;

            emit DivergenceCheck(positionId, divergenceBps, pos.divergenceThresholdBps, breached);

            if (breached) {
                _triggerExit(positionId, pair, divergenceBps);
            }
        }
    }

    // -------------------------------------------------------------------------
    // Trigger exit
    // -------------------------------------------------------------------------

    /**
     * @notice Emit Callback to Sepolia, instructing the callback contract to
     *         remove the LP position for `positionId`.
     */
    function _triggerExit(uint256 positionId, address pair, uint256 divergenceBps) internal {
        TrackedPosition storage pos = trackedPositions[positionId];

        pos.lastTriggeredAt = block.timestamp;
        pos.triggerCount++;

        bytes memory payload = abi.encodeWithSignature(
            "executeExit(address,uint256)",
            address(0), // sender — unused in callback
            positionId
        );

        emit Callback(SEPOLIA_CHAIN_ID, ilProtectionCallback, CALLBACK_GAS_LIMIT, payload);
        emit ExitTriggered(positionId, pair, divergenceBps);
    }

    // -------------------------------------------------------------------------
    // Pair subscription management (via self-callback on Reactive Network)
    // -------------------------------------------------------------------------

    function _subscribeToPair(address pair, uint256 chainId) internal {
        if (!subscribedPairs[pair]) {
            bytes memory payload =
                abi.encodeWithSignature("subscribeToPair(address,address,uint256)", address(0), pair, chainId);
            emit Callback(REACTIVE_CHAIN_ID, address(this), CALLBACK_GAS_LIMIT, payload);
            subscribedPairs[pair] = true;
            emit PairSubscribed(pair);
        }
    }

    function _unsubscribeFromPair(address pair, uint256 chainId) internal {
        if (subscribedPairs[pair]) {
            bytes memory payload =
                abi.encodeWithSignature("unsubscribeFromPair(address,address,uint256)", address(0), pair, chainId);
            emit Callback(REACTIVE_CHAIN_ID, address(this), CALLBACK_GAS_LIMIT, payload);
            subscribedPairs[pair] = false;
            emit PairUnsubscribed(pair);
        }
    }

    /**
     * @notice Called via self-callback on the Reactive Network to execute subscription
     */
    function subscribeToPair(address, address pair, uint256 chainId) external rnOnly {
        service.subscribe(chainId, pair, UNISWAP_V2_SYNC_TOPIC_0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    /**
     * @notice Called via self-callback on the Reactive Network to execute unsubscription
     */
    function unsubscribeFromPair(address, address pair, uint256 chainId) external rnOnly {
        service.unsubscribe(chainId, pair, UNISWAP_V2_SYNC_TOPIC_0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    /**
     * @notice Deactivates a position and decrements the pair's active count,
     *         triggering unsubscription if no more positions remain for that pair.
     */
    function _deactivatePosition(uint256 positionId) internal {
        if (trackedPositions[positionId].id != positionId) return;

        address pair = trackedPositions[positionId].pair;
        trackedPositions[positionId].status = PositionStatus.Exited;

        if (pairActiveCount[pair] > 0) {
            pairActiveCount[pair]--;
            if (pairActiveCount[pair] == 0) {
                _unsubscribeFromPair(pair, SEPOLIA_CHAIN_ID);
            }
        }

        emit PositionUntracked(pair, positionId);
    }

    /**
     * @notice Computes reserve-ratio divergence in basis points.
     *
     *   Entry ratio:   R_e = entryR0 / entryR1
     *   Current ratio: R_c = currentR0 / currentR1
     *
     *   To avoid floating point:
     *     divergenceBps = |R_c - R_e| / R_e * BPS_DENOMINATOR
     *                   = |currentR0 * entryR1 - entryR0 * currentR1|
     *                     / (entryR0 * currentR1) * BPS_DENOMINATOR
     *
     *   Uses Math.mulDiv for overflow-safe 256-bit arithmetic.
     */
    function _computeDivergenceBps(uint256 entryR0, uint256 entryR1, uint256 currentR0, uint256 currentR1)
        internal
        pure
        returns (uint256)
    {
        uint256 currentCross = Math.mulDiv(currentR0, entryR1, 1);
        uint256 entryCross = Math.mulDiv(entryR0, currentR1, 1);

        uint256 delta = currentCross > entryCross ? currentCross - entryCross : entryCross - currentCross;

        return Math.mulDiv(delta, BPS_DENOMINATOR, entryCross);
    }

    // -------------------------------------------------------------------------
    // Emergency / owner functions
    // -------------------------------------------------------------------------

    /**
     * @notice Manually force-subscribe a pair (emergency use)
     */
    function emergencySubscribeToPair(address pair, uint256 chainId) external onlyOwner {
        service.subscribe(chainId, pair, UNISWAP_V2_SYNC_TOPIC_0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
        subscribedPairs[pair] = true;
        emit PairSubscribed(pair);
    }

    /**
     * @notice Manually force-unsubscribe a pair (emergency use)
     */
    function emergencyUnsubscribeFromPair(address pair, uint256 chainId) external onlyOwner {
        service.unsubscribe(chainId, pair, UNISWAP_V2_SYNC_TOPIC_0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
        subscribedPairs[pair] = false;
        emit PairUnsubscribed(pair);
    }

    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        SafeERC20.safeTransfer(IERC20(token), to, amount);
    }

    function rescueAllERC20(address token, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to rescue");
        SafeERC20.safeTransfer(IERC20(token), to, balance);
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function withdrawAllETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        (bool success,) = payable(msg.sender).call{value: balance}("");
        require(success, "ETH transfer failed");
    }

    // -------------------------------------------------------------------------
    // View
    // -------------------------------------------------------------------------

    function getActivePositionsForPair(address pair) external view returns (uint256[] memory) {
        uint256[] storage all = pairPositions[pair];
        uint256 count = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (trackedPositions[all[i]].status == PositionStatus.Active) count++;
        }
        uint256[] memory active = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (trackedPositions[all[i]].status == PositionStatus.Active) {
                active[idx++] = all[i];
            }
        }
        return active;
    }
}
