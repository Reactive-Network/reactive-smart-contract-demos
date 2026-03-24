// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import "../../../lib/reactive-lib/src/interfaces/IReactive.sol";
import "../../../lib/reactive-lib/src/abstract-base/AbstractReactive.sol";

/**
 * @title GaslessDemoCrossChainAtomicSwapReactive
 * @notice Orchestrates the entire cross-chain atomic swap by subscribing to events on both the
 *         swap initiator and swap closer chains. Handles state synchronization, deposit
 *         confirmations, and triggers final completion on both chains automatically.
 * @dev Deploy a single instance on the Reactive Network. Requires the callback contracts
 *      to already be deployed on both participating chains.
 */
contract GaslessDemoCrossChainAtomicSwapReactive is IReactive, AbstractReactive {
    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event Subscribed(address indexed service_address, address indexed _contract, uint256 indexed topic_0);

    event CallbackSent(uint256 indexed destinationChainId, address indexed destinationContract, bytes32 indexed swapId);

    // -------------------------------------------------------------------------
    // Event topic constants
    // Precomputed keccak256 hashes of each event signature.
    // -------------------------------------------------------------------------

    uint256 private constant SWAP_INITIATED = 0xc4c6b2254f1c4a4e184fddbb16a1c56ad84bdf45912de2e20172e0904b343d79;
    // keccak256("SwapInitiated(bytes32,address,address,uint256,address,uint256,uint256,uint256,uint256)")

    uint256 private constant SWAP_ACKNOWLEDGED = 0xa9e34b54a07c1da140f0cbf37fab0bdfbe06fc3d9154760989b1d3b18991d1cf;
    // keccak256("SwapAcknowledged(bytes32,address,uint256)")

    uint256 private constant TOKENS_DEPOSITED = 0xf528889eb6fe3fb8560fd42c69d609d585adb06376da5191d03f2827cbab50fd;
    // keccak256("TokensDeposited(bytes32,address,address,uint256,uint256,bool)")

    uint256 private constant SWAP_COMPLETED = 0x25996b8e017c54246498598a3603332cf2bf351221c37ed1e483a17c2421a98c;
    // keccak256("SwapCompleted(bytes32,address,address,uint256)")

    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    // -------------------------------------------------------------------------
    // Immutable configuration (set at construction time)
    // -------------------------------------------------------------------------

    uint256 private immutable swap_initiator_chain_id;
    uint256 private immutable swap_closer_chain_id;
    address private immutable swap_initiator_contract;
    address private immutable swap_closer_contract;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @param _swap_initiator_chain_id Chain ID where swaps are initiated (e.g. 11155111 for Sepolia).
     * @param _swap_closer_chain_id Chain ID where swaps are acknowledged and closed (e.g. 5318008 for Kopli).
     * @param _swap_initiator_contract Callback contract address on the initiator chain.
     * @param _swap_closer_contract Callback contract address on the closer chain.
     */
    constructor(
        uint256 _swap_initiator_chain_id,
        uint256 _swap_closer_chain_id,
        address _swap_initiator_contract,
        address _swap_closer_contract
    ) payable {
        swap_initiator_chain_id = _swap_initiator_chain_id;
        swap_closer_chain_id = _swap_closer_chain_id;
        swap_initiator_contract = _swap_initiator_contract;
        swap_closer_contract = _swap_closer_contract;

        if (!vm) {
            // Initiator chain: SwapInitiated + TokensDeposited (user1)
            service.subscribe(
                swap_initiator_chain_id,
                swap_initiator_contract,
                SWAP_INITIATED,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                swap_initiator_chain_id,
                swap_initiator_contract,
                TOKENS_DEPOSITED,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            // Closer chain: SwapAcknowledged + TokensDeposited (user2)
            service.subscribe(
                swap_closer_chain_id,
                swap_closer_contract,
                SWAP_ACKNOWLEDGED,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                swap_closer_chain_id,
                swap_closer_contract,
                TOKENS_DEPOSITED,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    // -------------------------------------------------------------------------
    // IReactive — main entry point
    // -------------------------------------------------------------------------

    /**
     * @notice Called by the Reactive Network for every subscribed log event.
     * @dev Routes each event to the appropriate handler based on origin chain and topic.
     */
    function react(LogRecord calldata log) external vmOnly {
        if (log.chain_id == swap_initiator_chain_id && log._contract == swap_initiator_contract) {
            if (log.topic_0 == SWAP_INITIATED) {
                _handleSwapInitiated(log);
            } else if (log.topic_0 == TOKENS_DEPOSITED) {
                _handleTokensDepositedOrigin(log);
            }
        } else if (log.chain_id == swap_closer_chain_id && log._contract == swap_closer_contract) {
            if (log.topic_0 == SWAP_ACKNOWLEDGED) {
                _handleSwapAcknowledged(log);
            } else if (log.topic_0 == TOKENS_DEPOSITED) {
                _handleTokensDepositedDestination(log);
            }
        }
    }

    // -------------------------------------------------------------------------
    // Internal handlers
    // -------------------------------------------------------------------------

    /**
     * @dev SwapInitiated on the initiator chain → replicate swap info on the closer chain
     *      so that User2 can discover and acknowledge it there.
     *
     *      Event: SwapInitiated(bytes32 indexed swapId, address indexed user1,
     *                           address token1, uint256 amount1, address token2, uint256 amount2,
     *                           uint256 chainId1, uint256 chainId2, uint256 timeout)
     */
    function _handleSwapInitiated(LogRecord calldata log) private {
        bytes32 swap_id = bytes32(log.topic_1);
        address user1 = address(uint160(log.topic_2));

        (
            address token1,
            uint256 amount1,
            address token2,
            uint256 amount2,
            uint256 chain_id1,
            uint256 chain_id2,
            uint256 timeout
        ) = abi.decode(log.data, (address, uint256, address, uint256, uint256, uint256, uint256));

        bytes memory payload = abi.encodeWithSignature(
            "createSwapInfo(address,bytes32,address,address,uint256,address,uint256,uint256,uint256,uint256,uint256)",
            address(0), // sender (unused in callback)
            swap_id,
            user1,
            token1,
            amount1,
            token2,
            amount2,
            chain_id1,
            chain_id2,
            block.timestamp,
            timeout
        );

        emit Callback(swap_closer_chain_id, swap_closer_contract, CALLBACK_GAS_LIMIT, payload);
        emit CallbackSent(swap_closer_chain_id, swap_closer_contract, swap_id);
    }

    /**
     * @dev SwapAcknowledged on the closer chain → inform the initiator chain that User2
     *      has joined so User1 can proceed with their deposit.
     *
     *      Event: SwapAcknowledged(bytes32 indexed swapId, address indexed user2, uint256 chainId)
     */
    function _handleSwapAcknowledged(LogRecord calldata log) private {
        bytes32 swap_id = bytes32(log.topic_1);
        address user2 = address(uint160(log.topic_2));

        bytes memory payload = abi.encodeWithSignature(
            "updateSwapInfo(address,bytes32,uint8,address)",
            address(0),
            swap_id,
            uint8(2), // SwapState.Acknowledged
            user2
        );

        emit Callback(swap_initiator_chain_id, swap_initiator_contract, CALLBACK_GAS_LIMIT, payload);
        emit CallbackSent(swap_initiator_chain_id, swap_initiator_contract, swap_id);
    }

    /**
     * @dev TokensDeposited on the initiator chain (isUser1 == true) →
     *      update the closer chain so User2 knows they can now deposit.
     *
     *      Event: TokensDeposited(bytes32 indexed swapId, address indexed user,
     *                             address token, uint256 amount, uint256 chainId, bool isUser1)
     */
    function _handleTokensDepositedOrigin(LogRecord calldata log) private {
        bytes32 swap_id = bytes32(log.topic_1);

        (,,, bool is_user1) = abi.decode(log.data, (address, uint256, uint256, bool));

        if (!is_user1) return; // Only interested in User1 deposits from the initiator chain

        bytes memory payload = abi.encodeWithSignature(
            "updateSwapInfo(address,bytes32,uint8,address)",
            address(0),
            swap_id,
            uint8(3), // SwapState.User1Deposited
            address(0)
        );

        emit Callback(swap_closer_chain_id, swap_closer_contract, CALLBACK_GAS_LIMIT, payload);
        emit CallbackSent(swap_closer_chain_id, swap_closer_contract, swap_id);
    }

    /**
     * @dev TokensDeposited on the closer chain (isUser1 == false) →
     *      both parties have committed funds; trigger completeSwap() on both chains.
     *
     *      Order of callbacks:
     *        1. Update state to User2Deposited on the initiator chain.
     *        2. Complete swap on the initiator chain (releases token1 to User2).
     *        3. Complete swap on the closer chain   (releases token2 to User1).
     *
     *      Event: TokensDeposited(bytes32 indexed swapId, address indexed user,
     *                             address token, uint256 amount, uint256 chainId, bool isUser1)
     */
    function _handleTokensDepositedDestination(LogRecord calldata log) private {
        bytes32 swap_id = bytes32(log.topic_1);

        (,,, bool is_user1) = abi.decode(log.data, (address, uint256, uint256, bool));

        if (is_user1) return; // Only interested in User2 deposits from the closer chain

        // 1 — Sync state on initiator chain
        bytes memory update_payload = abi.encodeWithSignature(
            "updateSwapInfo(address,bytes32,uint8,address)",
            address(0),
            swap_id,
            uint8(4), // SwapState.User2Deposited
            address(0)
        );
        emit Callback(swap_initiator_chain_id, swap_initiator_contract, CALLBACK_GAS_LIMIT, update_payload);

        // 2 — Complete on initiator chain
        bytes memory complete_origin = abi.encodeWithSignature("completeSwap(address,bytes32)", address(0), swap_id);
        emit Callback(swap_initiator_chain_id, swap_initiator_contract, CALLBACK_GAS_LIMIT, complete_origin);

        // 3 — Complete on closer chain
        bytes memory complete_dest = abi.encodeWithSignature("completeSwap(address,bytes32)", address(0), swap_id);
        emit Callback(swap_closer_chain_id, swap_closer_contract, CALLBACK_GAS_LIMIT, complete_dest);

        emit CallbackSent(swap_initiator_chain_id, swap_initiator_contract, swap_id);
        emit CallbackSent(swap_closer_chain_id, swap_closer_contract, swap_id);
    }
}
