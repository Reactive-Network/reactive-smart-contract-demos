// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/interfaces/IReactive.sol';
import '../../../lib/reactive-lib/src/abstract-base/AbstractReactive.sol';

contract GaslessDemoCrossChainAtomicSwapReactive is IReactive, AbstractReactive {
    event Subscribed(
        address indexed service_address,
        address indexed _contract,
        uint256 indexed topic_0
    );

    event VM();

    // Updated event signatures to match the new contract
    uint256 private constant SWAP_INITIATED = 0xc4c6b2254f1c4a4e184fddbb16a1c56ad84bdf45912de2e20172e0904b343d79;
    uint256 private constant SWAP_ACKNOWLEDGED = 0xa9e34b54a07c1da140f0cbf37fab0bdfbe06fc3d9154760989b1d3b18991d1cf;
    uint256 private constant TOKENS_DEPOSITED = 0xf528889eb6fe3fb8560fd42c69d609d585adb06376da5191d03f2827cbab50fd;
    uint256 private constant SWAP_COMPLETED = 0x25996b8e017c54246498598a3603332cf2bf351221c37ed1e483a17c2421a98c;
    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    // State specific to ReactVM instance of the contract.
    uint256 private swap_initiator_chain_id;
    uint256 private swap_closer_chain_id;
    address private swap_initiator_contract;
    address private swap_closer_contract;

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
            // Subscribe to origin chain events
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
            
            // Subscribe to destination chain events
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

    // Methods specific to ReactVM instance of the contract.
    function react(LogRecord calldata log) external vmOnly {
        if (log.chain_id == swap_initiator_chain_id && log._contract == swap_initiator_contract) {
            // Events from Swap Initiator Chain
            if (log.topic_0 == SWAP_INITIATED) {
                // Create swap info on Swap Closer Chain
                handle_swap_initiated(log);
            } else if (log.topic_0 == TOKENS_DEPOSITED) {
                // User1 deposited, update Swap Closer Chain
                handle_tokens_deposited_origin(log);
            }

        } else if (log.chain_id == swap_closer_chain_id && log._contract == swap_closer_contract) {
            // Events from Swap Closer Chain

            if (log.topic_0 == SWAP_ACKNOWLEDGED) {
                // Update acknowledgment on Swap Initiator Chain
                handle_swap_acknowledged(log);
                
            } else if (log.topic_0 == TOKENS_DEPOSITED) {
                // User2 deposited, complete the swap
                handle_tokens_deposited_destination(log);
            }
        }
    }

    function handle_swap_initiated(LogRecord calldata log) private {
        // Extract swap data from log
        bytes32 swap_id = bytes32(log.topic_1);
        address user1 = address(uint160(log.topic_2));
        
        // Decode additional data from log.data
        // SwapInitiated(bytes32,address,address,uint256,address,uint256,uint256,uint256,uint256)
        (address token1, uint256 amount1, address token2, uint256 amount2, 
         uint256 chain_id1, uint256 chain_id2, uint256 timeout) = 
            abi.decode(log.data, (address, uint256, address, uint256, uint256, uint256, uint256));
        
        // Create swap info on Swap Closer Chain
        bytes memory payload = abi.encodeWithSignature(
            "createSwapInfo(address,bytes32,address,address,uint256,address,uint256,uint256,uint256,uint256,uint256)",
            address(0),
            swap_id,
            user1,
            token1,
            amount1,
            token2,
            amount2,
            chain_id1,
            chain_id2,
            block.timestamp, // initiatedAt
            timeout
        );
        
        emit Callback(swap_closer_chain_id, swap_closer_contract, CALLBACK_GAS_LIMIT, payload);
    }

    function handle_swap_acknowledged(LogRecord calldata log) private {
        // Extract data from log
        bytes32 swap_id = bytes32(log.topic_1);
        address user2 = address(uint160(log.topic_2));
        
        // Update Initiator Chain that user2 acknowledged the swap
        bytes memory payload = abi.encodeWithSignature(
            "updateSwapInfo(address,bytes32,uint8,address)",
            address(0),
            swap_id,
            uint8(2), // SwapState.Acknowledged
            user2
        );
        
        emit Callback(swap_initiator_chain_id, swap_initiator_contract, CALLBACK_GAS_LIMIT, payload);
    }

    function handle_tokens_deposited_origin(LogRecord calldata log) private {
        // Extract data from log
        bytes32 swap_id = bytes32(log.topic_1);
        
        // Decode deposit info from log.data
        // TokensDeposited(bytes32,address,address,uint256,uint256,bool)
        (, , , bool is_user1) = 
            abi.decode(log.data, (address, uint256, uint256, bool));
        
        // Only handle user1 deposits from Initiator chain
        if (is_user1) {
            // Update destination chain that user1 has deposited
            bytes memory payload = abi.encodeWithSignature(
                "updateSwapInfo(address,bytes32,uint8,address)",
                address(0),
                swap_id,
                uint8(3), // SwapState.User1Deposited
                address(0) // No user2 address needed for this update
            );
            
            emit Callback(swap_closer_chain_id, swap_closer_contract, CALLBACK_GAS_LIMIT, payload);
        }
    }

    function handle_tokens_deposited_destination(LogRecord calldata log) private {
        // Extract data from log
        bytes32 swap_id = bytes32(log.topic_1);
        
        // Decode deposit info from log.data
        // TokensDeposited(bytes32,address,address,uint256,uint256,bool)
        (, , , bool is_user1) = 
            abi.decode(log.data, (address, uint256, uint256, bool));
        
        // Only handle user2 deposits from Closer chain
        if (!is_user1) {
            // User2 has deposited, now complete the swap on both chains
            
            // First, update the state on Swap Initiator Chain
            bytes memory update_payload = abi.encodeWithSignature(
                "updateSwapInfo(address,bytes32,uint8,address)",
                address(0),
                swap_id,
                uint8(4), // SwapState.User2Deposited
                address(0)
            );
            emit Callback(swap_initiator_chain_id, swap_initiator_contract, CALLBACK_GAS_LIMIT, update_payload);
            
            // Then complete the swap on both chains
            bytes memory complete_origin_payload = abi.encodeWithSignature(
                "completeSwap(address,bytes32)",
                address(0),
                swap_id
            );
            emit Callback(swap_initiator_chain_id, swap_initiator_contract, CALLBACK_GAS_LIMIT, complete_origin_payload);
            
            bytes memory complete_dest_payload = abi.encodeWithSignature(
                "completeSwap(address,bytes32)",
                address(0),
                swap_id
            );
            emit Callback(swap_closer_chain_id, swap_closer_contract, CALLBACK_GAS_LIMIT, complete_dest_payload);
        }
    }
}