// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import '../../IReactive.sol';
import '../../AbstractReactive.sol';
import '../../ISystemContract.sol';

contract BasicDemoReactiveContract is IReactive, AbstractReactive {
    event Event(
        uint256 indexed chain_id,
        address indexed _contract,
        uint256 indexed topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes data,
        uint256 counter
    );

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    uint64 private constant GAS_LIMIT = 1000000;

    // State specific to reactive network instance of the contract

    address private _callback;

    // State specific to ReactVM instance of the contract

    uint256 public counter;

    constructor(address _service, address _contract, uint256 topic_0, address callback) {
        service = ISystemContract(payable(_service));
        bytes memory payload = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            _contract,
            topic_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result,) = address(service).call(payload);
        vm = !subscription_result;
        _callback = callback;
    }

    receive() external payable {}

    // Methods specific to ReactVM instance of the contract

    function react(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes calldata data,
        uint256 /* block_number */,
        uint256 /* op_code */
    ) external vmOnly {
        emit Event(chain_id, _contract, topic_0, topic_1, topic_2, topic_3, data, ++counter);
        if (topic_3 >= 0.1 ether) {
            bytes memory payload = abi.encodeWithSignature("callback(address)", address(0));
            emit Callback(chain_id, _callback, GAS_LIMIT, payload);
        }
    }

    // Methods for testing environment only

    function pretendVm() external {
        vm = true;
    }

    function subscribe(address _contract, uint256 topic_0) external {
        service.subscribe(
            SEPOLIA_CHAIN_ID,
            _contract,
            topic_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    function unsubscribe(address _contract, uint256 topic_0) external {
        service.unsubscribe(
            SEPOLIA_CHAIN_ID,
            _contract,
            topic_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    function resetCounter() external {
        counter = 0;
    }
}
