// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import '../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';

contract GaslessDemoCrossChainAtomicSwapCallback is AbstractCallback {
    
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
        address user1;           // Initiator on chain 1
        address user2;           // Acknowledger on chain 2
        address token1;          // Token on chain 1
        address token2;          // Token on chain 2
        uint256 amount1;         // Amount of token1
        uint256 amount2;         // Amount of token2
        uint256 chainId1;        // Swap Initiator chain ID
        uint256 chainId2;        // Swap Closer chain ID
        SwapState state;
        uint256 initiatedAt;
        uint256 timeout;         // Timeout in seconds
    }
    
    // Mapping from swap ID to swap info
    mapping(bytes32 => SwapInfo) public swaps;
    
    // Mapping to track user's active swaps
    mapping(address => bytes32[]) public userSwaps;
    
    // Events for Reactive Smart Contract to listen to
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
    
    event SwapAcknowledged(
        bytes32 indexed swapId,
        address indexed user2,
        uint256 chainId
    );
    
    event TokensDeposited(
        bytes32 indexed swapId,
        address indexed user,
        address token,
        uint256 amount,
        uint256 chainId,
        bool isUser1
    );
    
    event SwapCompleted(
        bytes32 indexed swapId,
        address user1,
        address user2,
        uint256 chainId
    );
    
    event SwapCancelled(
        bytes32 indexed swapId,
        string reason,
        uint256 chainId
    );
    
    event SwapInfoUpdated(
        bytes32 indexed swapId,
        SwapState newState,
        uint256 chainId
    );
    
    modifier onlyValidSwap(bytes32 swap_id) {
        require(swaps[swap_id].state != SwapState.None, "Swap does not exist");
        require(swaps[swap_id].state != SwapState.Completed, "Swap already completed");
        require(swaps[swap_id].state != SwapState.Cancelled, "Swap cancelled");
        _;
    }
    
    modifier onlyBeforeTimeout(bytes32 swap_id) {
        require(
            block.timestamp <= swaps[swap_id].initiatedAt + swaps[swap_id].timeout,
            "Swap timeout exceeded"
        );
        _;
    }
    
    constructor(address _callback_sender) AbstractCallback(_callback_sender) payable {
    }

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
        
        // Generate unique swap ID
        swap_id = keccak256(abi.encodePacked(
            msg.sender,
            token1,
            amount1,
            token2,
            amount2,
            block.chainid,
            chain_id2,
            block.timestamp,
            block.number
        ));
        
        require(swaps[swap_id].state == SwapState.None, "Swap ID collision");
        
        // Create swap info
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
        
        // Track user's swap
        userSwaps[msg.sender].push(swap_id);
        
        emit SwapInitiated(
            swap_id,
            msg.sender,
            token1,
            amount1,
            token2,
            amount2,
            block.chainid,
            chain_id2,
            timeout
        );
        
        return swap_id;
    }
    
    function acknowledgeSwap(bytes32 swap_id) 
        external 
        onlyValidSwap(swap_id)
        onlyBeforeTimeout(swap_id)
    {
        SwapInfo storage swap = swaps[swap_id];
        require(swap.state == SwapState.Initiated, "Swap not in initiated state");
        require(swap.chainId2 == block.chainid, "Wrong chain for acknowledgment");
        require(swap.user1 != msg.sender, "Cannot acknowledge own swap");
        
        // Update swap state
        swap.user2 = msg.sender;
        swap.state = SwapState.Acknowledged;
        
        // Track user's swap
        userSwaps[msg.sender].push(swap_id);
        
        emit SwapAcknowledged(swap_id, msg.sender, block.chainid);
    }
    
    function depositTokens(bytes32 swap_id) 
        external 
        onlyValidSwap(swap_id)
        onlyBeforeTimeout(swap_id)
    {
        SwapInfo storage swap = swaps[swap_id];
        
        if (msg.sender == swap.user1) {
            // User1 depositing
            require(swap.state == SwapState.Acknowledged, "Swap not acknowledged yet");
            require(swap.chainId1 == block.chainid, "Wrong chain for user1 deposit");
            
            // Transfer tokens from user1 to contract
            IERC20(swap.token1).transferFrom(msg.sender, address(this), swap.amount1);
            
            // Update state
            swap.state = SwapState.User1Deposited;
            
            emit TokensDeposited(
                swap_id,
                msg.sender,
                swap.token1,
                swap.amount1,
                block.chainid,
                true
            );
            
        } else if (msg.sender == swap.user2) {
            // User2 depositing
            require(swap.state == SwapState.User1Deposited, "User1 has not deposited yet");
            require(swap.chainId2 == block.chainid, "Wrong chain for user2 deposit");
            
            // Transfer tokens from user2 to contract
            IERC20(swap.token2).transferFrom(msg.sender, address(this), swap.amount2);
            
            // Update state
            swap.state = SwapState.User2Deposited;
            
            emit TokensDeposited(
                swap_id,
                msg.sender,
                swap.token2,
                swap.amount2,
                block.chainid,
                false
            );
            
        } else {
            revert("Only swap participants can deposit");
        }
    }
    
    function completeSwap(
        address /* spender */,
        bytes32 swap_id
        ) external 
        onlyValidSwap(swap_id)
    {
        SwapInfo storage swap = swaps[swap_id];
        require(swap.state == SwapState.User2Deposited, "Both users must deposit first");
        
        // Determine which chain we're on and transfer accordingly
        if (block.chainid == swap.chainId1) {
            // On chain 1: transfer token1 to user2
            IERC20(swap.token1).transfer(swap.user2, swap.amount1);
        } else if (block.chainid == swap.chainId2) {
            // On chain 2: transfer token2 to user1  
            IERC20(swap.token2).transfer(swap.user1, swap.amount2);
        }
        
        // Update state
        swap.state = SwapState.Completed;
        
        emit SwapCompleted(swap_id, swap.user1, swap.user2, block.chainid);
    }
    
    function cancelSwap(
        bytes32 swap_id,
        string calldata reason
        )external 
        onlyValidSwap(swap_id)
    {
        SwapInfo storage swap = swaps[swap_id];
        
        // Allow cancellation by users or after timeout
        bool canCancel = (
            msg.sender == swap.user1 || 
            msg.sender == swap.user2 ||
            block.timestamp > swap.initiatedAt + swap.timeout
        );
        
        require(canCancel, "Not authorized to cancel");
        
        // Refund deposited tokens
        if (swap.state == SwapState.User1Deposited || swap.state == SwapState.User2Deposited) {
            if (block.chainid == swap.chainId1 && swap.state >= SwapState.User1Deposited) {
                IERC20(swap.token1).transfer(swap.user1, swap.amount1);
            }
            if (block.chainid == swap.chainId2 && swap.state == SwapState.User2Deposited) {
                IERC20(swap.token2).transfer(swap.user2, swap.amount2);
            }
        }
        
        swap.state = SwapState.Cancelled;
        
        emit SwapCancelled(swap_id, reason, block.chainid);
    }
    
    function updateSwapInfo(
        address /* spender */,
        bytes32 swap_id, 
        SwapState new_state,
        address user2
    ) external {
        SwapInfo storage swap = swaps[swap_id];
        
        // For initiated swaps, create the swap info if it doesn't exist
        if (swap.state == SwapState.None && new_state == SwapState.Initiated) {
            // This would be populated by the reactive contract with full swap details
            swap.state = new_state;
        } else {
            require(swap.state != SwapState.None, "Swap does not exist");
            
            // Update state based on cross-chain updates
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
    
    function createSwapInfo(
        address /* spender */,
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
    ) external {
        require(swaps[swap_id].state == SwapState.None, "Swap already exists");
        
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
    
    // View functions
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