// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';
import '../../../lib/reactive-lib/src/abstract-base/AbstractPausableReactive.sol';

contract Monitoring is AbstractPausableReactive, AbstractCallback {
    event Notification(
        uint256 indexed topic1,
        uint256 indexed topic2,
        uint256 indexed topic3,
        uint256 chainId,
        address srcContract,
        bytes data
    );

    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    uint256 private chainId;
    address private contractAddr;
    uint256 private topic0;

    constructor(
        uint256 _chainId,
        address _contractAddr,
        uint256 _topic0
    ) AbstractCallback(address(SERVICE_ADDR)) payable {
        chainId = _chainId;
        contractAddr = _contractAddr;
        topic0 = _topic0;

        if (!vm) {
            service.subscribe(
                _chainId,
                _contractAddr,
                _topic0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    function shouldCallback(
        uint256 /* evtChainId */,
        address /* evtContract */,
        uint256 /* evtTopic0 */,
        uint256 /* evtTopic1 */,
        uint256 /* evtTopic2 */,
        uint256 /* evtTopic3 */,
        bytes calldata /* data */
    ) virtual internal pure returns (bool) {
        return true;
    }

    function callback(
        address rvmId,
        uint256 evtChainId,
        address evtContract,
        uint256 /* evtTopic0 */,
        uint256 evtTopic1,
        uint256 evtTopic2,
        uint256 evtTopic3,
        bytes calldata evtData
    ) virtual external authorizedSenderOnly rvmIdOnly(rvmId) {
        emit Notification(
            evtTopic1,
            evtTopic2,
            evtTopic3,
            evtChainId,
            evtContract,
            evtData
        );
    }

    function getPausableSubscriptions() internal view override returns (Subscription[] memory) {
        Subscription[] memory result = new Subscription[](1);
        result[0] = Subscription(
            chainId,
            contractAddr,
            topic0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return result;
    }

    function react(LogRecord calldata log) external vmOnly {
        if (shouldCallback(
            log.chain_id,
            log._contract,
            log.topic_0,
            log.topic_1,
            log.topic_2,
            log.topic_3,
            log.data
        )) {
            bytes memory payload = abi.encodeWithSignature(
                "callback(address,uint256,address,uint256,uint256,uint256,uint256,bytes)",
                address(0),
                log.chain_id,
                log._contract,
                log.topic_0,
                log.topic_1,
                log.topic_2,
                log.topic_3,
                log.data
            );
            emit Callback(block.chainid, address(this), CALLBACK_GAS_LIMIT, payload);
        }
    }
}
