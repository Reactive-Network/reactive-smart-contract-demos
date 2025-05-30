// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/abstract-base/AbstractReactive.sol';
import './ApprovalService.sol';

contract ApprovalListener is AbstractReactive {
    uint256 private constant SUBSCRIBE_TOPIC_0 = 0x1aec2cf998e5b9daa15739cf56ce9bb0f29355de099191a2118402e5ac0805c8;
    uint256 private constant UNSUBSCRIBE_TOPIC_0 = 0xeed050308c603899d7397c26bdccda0810c3ccc6e9730a8a10c452b522f8edf4;
    uint256 private constant APPROVAL_TOPIC_0 = 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;
    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    address private owner;
    ApprovalService private approval_service;

    uint256 private reactiveChainId;
    uint256 private destinationChainId;

    constructor(
        uint256 destinationChainId_,
        ApprovalService service_
    ) payable {
        owner = msg.sender;
        approval_service = service_;
        reactiveChainId = block.chainid;
        destinationChainId = destinationChainId_;

        if (!vm) {
            service.subscribe(
                destinationChainId,
                address(approval_service),
                SUBSCRIBE_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                destinationChainId,
                address(approval_service),
                UNSUBSCRIBE_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    modifier callbackOnly(address evm_id) {
        require(msg.sender == address(service), 'Callback only');
        require(evm_id == owner, 'Wrong EVM ID');
        _;
    }

    // Methods specific to reactive network contract instance
    function subscribe(address rvm_id, address subscriber) external rnOnly callbackOnly(rvm_id) {
        service.subscribe(
            destinationChainId,
            address(0),
            APPROVAL_TOPIC_0,
            REACTIVE_IGNORE,
            uint256(uint160(subscriber)),
            REACTIVE_IGNORE
        );
    }

    function unsubscribe(address rvm_id, address subscriber) external rnOnly callbackOnly(rvm_id) {
        service.unsubscribe(
            destinationChainId,
            address(0),
            APPROVAL_TOPIC_0,
            REACTIVE_IGNORE,
            uint256(uint160(subscriber)),
            REACTIVE_IGNORE
        );
    }

    // Methods specific to ReactVM contract instance
    function react(LogRecord calldata log) external vmOnly {
        if (log.topic_0 == SUBSCRIBE_TOPIC_0) {
            bytes memory payload = abi.encodeWithSignature(
                "subscribe(address,address)",
                address(0),
                address(uint160(log.topic_1))
            );
            emit Callback(reactiveChainId, address(this), CALLBACK_GAS_LIMIT, payload);
        } else if (log.topic_0 == UNSUBSCRIBE_TOPIC_0) {
            bytes memory payload = abi.encodeWithSignature(
                "unsubscribe(address,address)",
                address(0),
                address(uint160(log.topic_1))
            );
            emit Callback(reactiveChainId, address(this), CALLBACK_GAS_LIMIT, payload);
        } else {
            (uint256 amount) = abi.decode(log.data, (uint256));
            bytes memory payload = abi.encodeWithSignature(
                "onApproval(address,address,address,address,uint256)",
                address(0),
                address(uint160(log.topic_2)),
                address(uint160(log.topic_1)),
                log._contract,
                amount
            );
            emit Callback(destinationChainId, address(approval_service), CALLBACK_GAS_LIMIT, payload);
        }
    }
}
