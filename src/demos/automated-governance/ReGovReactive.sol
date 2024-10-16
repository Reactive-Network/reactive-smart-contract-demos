// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;


import "../../IReactive.sol";
import "../../AbstractReactive.sol";
import "../../ISubscriptionService.sol";

contract ReGovReactive is IReactive, AbstractReactive {

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    uint256 private constant VOTE_FOR_THRESOLD_REACH_TOPIC_0 =0x7edbeb06298438692f5e60c369b3d70cf26194c2263ff97ab5b32cecbddad8a7 ;
    uint256 private constant VOTE_AGAINST_THRESOLD_REACH_TOPIC_0 = 0xba3d34a559bd7600063768ee32172d8872b43d899ccd8ca2f9e9849e289e9fa2
;
    uint256 private constant DEADLINE_REACH_TOPIC_0 =0xecbc3a8bcc8ece0c1c67901dca8b46a78df89c54d4c702fd932f3ad8e1b7241e ;

    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;


    address private l1;

    constructor(address _l1) {
        
        bytes memory payload1 = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            _l1,
            VOTE_FOR_THRESOLD_REACH_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result1,) = address(service).call(payload1);
        if (!subscription_result1) {
            vm = true;
        }
        bytes memory payload2 = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            _l1,
            VOTE_AGAINST_THRESOLD_REACH_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result2,) = address(service).call(payload2);
        if (!subscription_result2) {
            vm = true;
        }
        bytes memory payload3 = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            _l1,
            DEADLINE_REACH_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result3,) = address(service).call(payload3);
        if (!subscription_result3) {
            vm = true;
        }

        l1 = _l1;
        
    }

    receive() external payable {}
    

    function react(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes calldata data,
        uint256 /* block number */,
        uint256 /* op_code */
    ) external vmOnly {
        if (topic_0 == VOTE_FOR_THRESOLD_REACH_TOPIC_0) {
           
            bytes memory payload = abi.encodeWithSignature(
                "executeProposal(address,uint256)",
                address(0),
                topic_1
            );
            emit Callback(chain_id, l1, CALLBACK_GAS_LIMIT, payload);
        } else if (topic_0 == VOTE_AGAINST_THRESOLD_REACH_TOPIC_0) {
            
            
            bytes memory payload = abi.encodeWithSignature(
                "DeleteProposal(address,uint256)",
                address(0),
                topic_1
            );
            emit Callback(chain_id, l1, CALLBACK_GAS_LIMIT, payload);
        } else if (topic_0 == DEADLINE_REACH_TOPIC_0) {
            bytes memory payload = abi.encodeWithSignature(
                "executeProposal(address,uint256)",
                address(0),
                topic_1
            );
            emit Callback(chain_id, l1, CALLBACK_GAS_LIMIT, payload);
        }
    }
}