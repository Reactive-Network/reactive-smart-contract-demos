// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/interfaces/ISystemContract.sol';
import '../../../lib/reactive-lib/src/abstract-base/AbstractPausableReactive.sol';

contract BasicCronContract is AbstractPausableReactive {

    uint256 public CRON_TOPIC;
    uint64 private constant GAS_LIMIT = 1000000;

    constructor(
        address _service,
        uint256 _cronTopic
    ) payable {
        service = ISystemContract(payable(_service));
        CRON_TOPIC = _cronTopic;

        if (!vm) {
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

    function getPausableSubscriptions() internal view override returns (Subscription[] memory) {
        Subscription[] memory result = new Subscription[](1);
        result[0] = Subscription(
            block.chainid,
            address(service),
            CRON_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return result;
    }

    function react(LogRecord calldata log) external vmOnly {
        if (log.topic_0 == CRON_TOPIC) {
            emit Callback(
                block.chainid,
                address(this),
                GAS_LIMIT,
                abi.encodeWithSignature("callback(address)", address(0)));
        }
    }
}

