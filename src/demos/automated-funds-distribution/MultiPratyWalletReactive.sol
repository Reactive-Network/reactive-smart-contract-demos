// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;


import "../../IReactive.sol";
import "../../AbstractReactive.sol";
import "../../ISubscriptionService.sol";

contract MultiPratyWalletReactive is IReactive, AbstractReactive {

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    uint256 private constant WALLET_CLOSED_TOPIC_0 =0xfa2763f7373a68fe3e9319f043584ac47e91ba6a95bef184a5a5ed00d198bba9;
    uint256 private constant SHARE_HOLDER_LEFT_TOPIC_0=0x5d6712e456ca571022e39ac7fef2dc1faf6c7d5f308ad90462f775c670896e1c;
    uint256 private constant FUND_RECIEVED_TOPIC_0=0x8e47b87b0ef542cdfa1659c551d88bad38aa7f452d2bbb349ab7530dfec8be8f;
    
    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;


    address private l1;

    constructor( address _l1) {
        
        bytes memory payload1 = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            _l1,
            WALLET_CLOSED_TOPIC_0,
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
            SHARE_HOLDER_LEFT_TOPIC_0,
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
            FUND_RECIEVED_TOPIC_0,
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


    function react(
        uint256 chain_id,
        address /*_contract*/,
        uint256 topic_0,
        uint256 /*topic_1*/,
        uint256 /*topic_2*/,
        uint256 /*topic_3*/,
        bytes calldata /*data*/,
        uint256 /* block number */,
        uint256 /* op_code */
    ) external vmOnly {
        if (topic_0 == FUND_RECIEVED_TOPIC_0) {
           
            bytes memory payload = abi.encodeWithSignature(
                "distributeAllFunds(address)",
                address(0)
            
            );
            emit Callback(chain_id, l1, CALLBACK_GAS_LIMIT, payload);
        }
        if (topic_0 == WALLET_CLOSED_TOPIC_0) {
           
            bytes memory payload = abi.encodeWithSignature(
                "updateShares(address)",
                address(0)
            
            );
            emit Callback(chain_id, l1, CALLBACK_GAS_LIMIT, payload);
        }

        if (topic_0 == SHARE_HOLDER_LEFT_TOPIC_0) {
           
            bytes memory payload = abi.encodeWithSignature(
                "updateShares(address)",
                address(0)
            
            );
            emit Callback(chain_id, l1, CALLBACK_GAS_LIMIT, payload);
        }
    }
    receive() external payable{}
}