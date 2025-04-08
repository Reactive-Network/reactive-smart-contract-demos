// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/interfaces/ISystemContract.sol';
import '../../../lib/reactive-lib/src/abstract-base/AbstractPausableReactive.sol';

contract BasicDemoReactiveContract is AbstractPausableReactive {

    uint256 public destinationChainId;
    uint256 public cronTopic;
    uint256 public topic_0;
    uint64 private constant GAS_LIMIT = 1000000;
    address private callback;

    constructor(
        address _service,
        uint256 _originChainId,
        uint256 _destinationChainId,
        address _originContract,
        uint256 _topic_0,
        uint256 _cronTopic,
        address _callback
    ) payable {
        service = ISystemContract(payable(_service));

        destinationChainId = _destinationChainId;
        topic_0 = _topic_0;
        cronTopic = _cronTopic;
        callback = _callback;

        if (!vm) {
            service.subscribe(
                _originChainId,
                _originContract,
                topic_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );

            if (_cronTopic != 0) {
                service.subscribe(
                    block.chainid,
                    address(service),
                    _cronTopic,
                    REACTIVE_IGNORE,
                    REACTIVE_IGNORE,
                    REACTIVE_IGNORE
                );
            }
        }
    }

    function getPausableSubscriptions() internal view override returns (Subscription[] memory) {
        if (cronTopic == 0) {
            return new Subscription[](0);
        }
        Subscription[] memory result = new Subscription[](1);
        result[0] = Subscription(
            block.chainid,
            address(service),
            cronTopic,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return result;
    }

    function react(LogRecord calldata log) external vmOnly {
        if (log.topic_0 == topic_0) {
            if (log.topic_3 >= 0.01 ether) {
                bytes memory payload = abi.encodeWithSignature("callback(address)", address(0));
                emit Callback(destinationChainId, callback, GAS_LIMIT, payload);
            }
        } else if (log.topic_0 == cronTopic) {
            bytes memory payload = abi.encodeWithSignature("callback(address)", address(0));
            emit Callback(destinationChainId, callback, GAS_LIMIT, payload);
        }
    }
}
