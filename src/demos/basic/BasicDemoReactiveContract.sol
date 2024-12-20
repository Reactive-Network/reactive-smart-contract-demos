// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/interfaces/IReactive.sol';
import '../../../lib/reactive-lib/src/abstract-base/AbstractReactive.sol';
import '../../../lib/reactive-lib/src/interfaces/ISystemContract.sol';

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

    constructor(
        address _service,
        address _contract,
        uint256 topic_0,
        address callback
    ) payable {
        service = ISystemContract(payable(_service));
        if (!vm) {
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                _contract,
                topic_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
        _callback = callback;
    }

    // Methods specific to ReactVM instance of the contract
    function react(LogRecord calldata log) external vmOnly {
        emit Event(
            log.chain_id,
            log._contract,
            log.topic_0,
            log.topic_1,
            log.topic_2,
            log.topic_3,
            log.data,
            ++counter
        );

        if (log.topic_3 >= 0.01 ether) {
            bytes memory payload = abi.encodeWithSignature("callback(address)", address(0));
            emit Callback(log.chain_id, _callback, GAS_LIMIT, payload);
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
