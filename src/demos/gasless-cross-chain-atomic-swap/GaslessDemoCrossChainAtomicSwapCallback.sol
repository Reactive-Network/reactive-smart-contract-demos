// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol";

/**
 * @title GaslessDemoCrossChainAtomicSwapCallback
 * @notice Manages the swap lifecycle on each chain — initiation, acknowledgment, deposit, and completion.
 * @dev Deploy one instance on each participating chain. The reactive contract handles all cross-chain
 *      state synchronization automatically. Users interact with this contract directly; the RSC handles
 *      completion callbacks.
 */
contract GaslessDemoCrossChainAtomicSwapCallback is AbstractCallback {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Types
    // -------------------------------------------------------------------------

    enum SwapState {
        None,
        Initiated,
        Acknowledged,
        User1Deposited,
        User2Deposited,
        Completed,
        Cancelled
    }

    struct SwapInfo {
        address user1; // Initiator on chain 1
        address user2; // Acknowledger on chain 2
        address token1; // Token on chain 1
        address token2; // Token on chain 2
        uint256 amount1; // Amount of token1
        uint256 amount2; // Amount of token2
        uint256 chainId1; // Swap Initiator chain ID
        uint256 chainId2; // Swap Closer chain ID
        SwapState state;
        uint256 initiatedAt;
        uint256 timeout; // Timeout in seconds
    }

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    mapping(bytes32 => SwapInfo) public swaps;
    mapping(address => bytes32[]) public userSwaps;

    // -------------------------------------------------------------------------
    // Events (monitored by the Reactive contract)
    // -------------------------------------------------------------------------

    event SwapInitiated(
        bytes32 indexed swapId,
        address indexed user1,
        address token1,
        uint256 amount1,
        address token2,
        uint256 amount2,
        uint256 chainId1,
        uint256 chainId2,
        uint256 timeout
    );

    event SwapAcknowledged(bytes32 indexed swapId, address indexed user2, uint256 chainId);

    event TokensDeposited(
        bytes32 indexed swapId, address indexed user, address token, uint256 amount, uint256 chainId, bool isUser1
    );

    event SwapCompleted(bytes32 indexed swapId, address user1, address user2, uint256 chainId);

    event SwapCancelled(bytes32 indexed swapId, string reason, uint256 chainId);

    event SwapInfoUpdated(bytes32 indexed swapId, SwapState newState, uint256 chainId);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error SwapDoesNotExist(bytes32 swapId);
    error SwapAlreadyCompleted(bytes32 swapId);
    error SwapAlreadyCancelled(bytes32 swapId);
    error SwapTimedOut(bytes32 swapId);
    error SwapAlreadyExists(bytes32 swapId);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyValidSwap(bytes32 swap_id) {
        if (swaps[swap_id].state == SwapState.None) revert SwapDoesNotExist(swap_id);
        if (swaps[swap_id].state == SwapState.Completed) revert SwapAlreadyCompleted(swap_id);
        if (swaps[swap_id].state == SwapState.Cancelled) revert SwapAlreadyCancelled(swap_id);
        _;
    }

    modifier onlyBeforeTimeout(bytes32 swap_id) {
        if (block.timestamp > swaps[swap_id].initiatedAt + swaps[swap_id].timeout) {
            revert SwapTimedOut(swap_id);
        }
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _callback_sender) payable AbstractCallback(_callback_sender) {}

    // -------------------------------------------------------------------------
    // User-facing functions
    // -------------------------------------------------------------------------

    /**
     * @notice Initiates a new cross-chain atomic swap.
     * @param token1 Token to sell on this chain.
     * @param amount1 Amount of token1 to sell.
     * @param token2 Token expected in return on the destination chain.
     * @param amount2 Amount of token2 expected.
     * @param chain_id2 Chain ID of the swap closer chain.
     * @param timeout Duration in seconds before the swap expires (1 hour – 7 days).
     * @return swap_id Unique identifier for this swap.
     */
    function initiateSwap(
        address token1,
        uint256 amount1,
        address token2,
        uint256 amount2,
        uint256 chain_id2,
        uint256 timeout
    ) external returns (bytes32 swap_id) {
        require(token1 != address(0), "Invalid token1 address");
        require(token2 != address(0), "Invalid token2 address");
        require(amount1 > 0, "Amount1 must be greater than 0");
        require(amount2 > 0, "Amount2 must be greater than 0");
        require(chain_id2 != block.chainid, "Cannot swap on same chain");
        require(timeout >= 1 hours && timeout <= 7 days, "Invalid timeout");

        swap_id = keccak256(
            abi.encodePacked(
                msg.sender, token1, amount1, token2, amount2, block.chainid, chain_id2, block.timestamp, block.number
            )
        );

        if (swaps[swap_id].state != SwapState.None) revert SwapAlreadyExists(swap_id);

        swaps[swap_id] = SwapInfo({
            user1: msg.sender,
            user2: address(0),
            token1: token1,
            token2: token2,
            amount1: amount1,
            amount2: amount2,
            chainId1: block.chainid,
            chainId2: chain_id2,
            state: SwapState.Initiated,
            initiatedAt: block.timestamp,
            timeout: timeout
        });

        userSwaps[msg.sender].push(swap_id);

        emit SwapInitiated(swap_id, msg.sender, token1, amount1, token2, amount2, block.chainid, chain_id2, timeout);
    }

    /**
     * @notice User2 acknowledges participation in a swap on the closer chain.
     * @param swap_id The swap ID to acknowledge.
     */
    function acknowledgeSwap(bytes32 swap_id) external onlyValidSwap(swap_id) onlyBeforeTimeout(swap_id) {
        SwapInfo storage swap = swaps[swap_id];
        require(swap.state == SwapState.Initiated, "Swap not in initiated state");
        require(swap.chainId2 == block.chainid, "Wrong chain for acknowledgment");
        require(swap.user1 != msg.sender, "Cannot acknowledge own swap");

        swap.user2 = msg.sender;
        swap.state = SwapState.Acknowledged;

        userSwaps[msg.sender].push(swap_id);

        emit SwapAcknowledged(swap_id, msg.sender, block.chainid);
    }

    /**
     * @notice Deposit tokens into the swap contract. User1 deposits on chain 1 after acknowledgment;
     *         User2 deposits on chain 2 after User1 has deposited.
     * @param swap_id The swap ID to deposit for.
     */
    function depositTokens(bytes32 swap_id) external onlyValidSwap(swap_id) onlyBeforeTimeout(swap_id) {
        SwapInfo storage swap = swaps[swap_id];

        if (msg.sender == swap.user1) {
            require(swap.state == SwapState.Acknowledged, "Swap not acknowledged yet");
            require(swap.chainId1 == block.chainid, "Wrong chain for user1 deposit");

            IERC20(swap.token1).safeTransferFrom(msg.sender, address(this), swap.amount1);
            swap.state = SwapState.User1Deposited;

            emit TokensDeposited(swap_id, msg.sender, swap.token1, swap.amount1, block.chainid, true);
        } else if (msg.sender == swap.user2) {
            require(swap.state == SwapState.User1Deposited, "User1 has not deposited yet");
            require(swap.chainId2 == block.chainid, "Wrong chain for user2 deposit");

            IERC20(swap.token2).safeTransferFrom(msg.sender, address(this), swap.amount2);
            swap.state = SwapState.User2Deposited;

            emit TokensDeposited(swap_id, msg.sender, swap.token2, swap.amount2, block.chainid, false);
        } else {
            revert("Only swap participants can deposit");
        }
    }

    // -------------------------------------------------------------------------
    // RSC callback functions (called by the Reactive Network)
    // -------------------------------------------------------------------------

    /**
     * @notice Completes the swap by distributing tokens to the counterparty.
     *         Called by the RSC on both chains once both deposits are confirmed.
     * @dev The `sender` parameter is required by the callback pattern but is unused here.
     */
    function completeSwap(
        address, /* sender */
        bytes32 swap_id
    )
        external
        authorizedSenderOnly
        onlyValidSwap(swap_id)
    {
        SwapInfo storage swap = swaps[swap_id];
        require(swap.state == SwapState.User2Deposited, "Both users must deposit first");

        if (block.chainid == swap.chainId1) {
            IERC20(swap.token1).safeTransfer(swap.user2, swap.amount1);
        } else if (block.chainid == swap.chainId2) {
            IERC20(swap.token2).safeTransfer(swap.user1, swap.amount2);
        }

        swap.state = SwapState.Completed;

        emit SwapCompleted(swap_id, swap.user1, swap.user2, block.chainid);
    }

    /**
     * @notice Cancels a swap and refunds deposited tokens.
     *         Can be called by either participant or by the RSC after timeout.
     */
    function cancelSwap(bytes32 swap_id, string calldata reason) external onlyValidSwap(swap_id) {
        SwapInfo storage swap = swaps[swap_id];

        bool canCancel =
            (msg.sender == swap.user1 || msg.sender == swap.user2 || block.timestamp > swap.initiatedAt + swap.timeout);
        require(canCancel, "Not authorized to cancel");

        if (swap.state == SwapState.User1Deposited || swap.state == SwapState.User2Deposited) {
            if (block.chainid == swap.chainId1 && swap.state >= SwapState.User1Deposited) {
                IERC20(swap.token1).safeTransfer(swap.user1, swap.amount1);
            }
            if (block.chainid == swap.chainId2 && swap.state == SwapState.User2Deposited) {
                IERC20(swap.token2).safeTransfer(swap.user2, swap.amount2);
            }
        }

        swap.state = SwapState.Cancelled;

        emit SwapCancelled(swap_id, reason, block.chainid);
    }

    /**
     * @notice Synchronises swap state from a cross-chain event.
     *         Called by the RSC to mirror state changes on the counterpart chain.
     */
    function updateSwapInfo(
        address, /* sender */
        bytes32 swap_id,
        SwapState new_state,
        address user2
    )
        external
        authorizedSenderOnly
    {
        SwapInfo storage swap = swaps[swap_id];

        if (swap.state == SwapState.None && new_state == SwapState.Initiated) {
            swap.state = new_state;
        } else {
            require(swap.state != SwapState.None, "Swap does not exist");

            if (new_state == SwapState.Acknowledged && swap.state == SwapState.Initiated) {
                swap.user2 = user2;
                swap.state = new_state;
                if (user2 != address(0)) {
                    userSwaps[user2].push(swap_id);
                }
            } else if (new_state == SwapState.User1Deposited && swap.state == SwapState.Acknowledged) {
                swap.state = new_state;
            } else if (new_state == SwapState.User2Deposited && swap.state == SwapState.User1Deposited) {
                swap.state = new_state;
            }
        }

        emit SwapInfoUpdated(swap_id, new_state, block.chainid);
    }

    /**
     * @notice Creates a full copy of swap info on the closer chain.
     *         Called by the RSC after it detects a SwapInitiated event on the origin chain.
     */
    function createSwapInfo(
        address, /* sender */
        bytes32 swap_id,
        address user1,
        address token1,
        uint256 amount1,
        address token2,
        uint256 amount2,
        uint256 chain_id1,
        uint256 chain_id2,
        uint256 initiated_at,
        uint256 timeout
    ) external authorizedSenderOnly {
        if (swaps[swap_id].state != SwapState.None) revert SwapAlreadyExists(swap_id);

        swaps[swap_id] = SwapInfo({
            user1: user1,
            user2: address(0),
            token1: token1,
            token2: token2,
            amount1: amount1,
            amount2: amount2,
            chainId1: chain_id1,
            chainId2: chain_id2,
            state: SwapState.Initiated,
            initiatedAt: initiated_at,
            timeout: timeout
        });

        emit SwapInfoUpdated(swap_id, SwapState.Initiated, block.chainid);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    function getSwapInfo(bytes32 swap_id) external view returns (SwapInfo memory) {
        return swaps[swap_id];
    }

    function getUserSwaps(address user) external view returns (bytes32[] memory) {
        return userSwaps[user];
    }

    function getSwapState(bytes32 swap_id) external view returns (SwapState) {
        return swaps[swap_id].state;
    }

    function isSwapExpired(bytes32 swap_id) external view returns (bool) {
        SwapInfo memory swap = swaps[swap_id];
        return block.timestamp > swap.initiatedAt + swap.timeout;
    }
}
