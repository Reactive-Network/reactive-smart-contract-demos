// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
pragma abicoder v2;

import "../../../../IReactive.sol";
import "../../../../AbstractReactive.sol";
import "../../../../ISubscriptionService.sol";


contract ReactiveWithPermitContract is IReactive,AbstractReactive {
    

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint64 private constant GAS_LIMIT = 1000000;
    uint256 constant TOPIC_0 = 0x79c488d5c1f559341a4ff5f993e3ec18efc5c3c90595752c9d89d50fae65c4d2; // Topic of the SwapApproved event


   
    address private originContract;


    constructor( address _originContract) {
        _subscribe(_originContract, TOPIC_0);
        originContract = _originContract;
    }

    receive() external payable {}

    function react(
        uint256 chain_id,
        address, /*_contract */
        uint256, /* topic_0 */
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes calldata data,
        uint256, /* block_number */
        uint256 /* op_code */
    ) external vmOnly {
        (uint256 amountIn, uint256 amountOutMin, uint24 fee) = abi.decode(data, (uint256, uint256, uint24));

        bytes memory payload = abi.encodeWithSignature(
            "callback(address,address,address,address,uint256,uint256,uint24)",
            address(0),
            address(uint160(topic_1)),
            address(uint160(topic_2)),
            address(uint160(topic_3)),
            amountIn,
            amountOutMin,
            fee
        );

        emit Callback(chain_id, originContract, GAS_LIMIT, payload);
    }


    function _subscribe(address _originContract, uint256 topic) private {
        bytes memory payload = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            _originContract,
            topic,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result,) = address(service).call(payload);
        if (!subscription_result) {
            vm = true;
        }
    }


    function subscribe(address _contract, uint256 topic_0) external {
        service.subscribe(SEPOLIA_CHAIN_ID, _contract, topic_0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    function unsubscribe(address _contract, uint256 topic_0) external {
        service.unsubscribe(SEPOLIA_CHAIN_ID, _contract, topic_0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }
}

