// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/abstract-base/AbstractReactive.sol';
import '../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';

interface IMailbox {
    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external payable returns (bytes32 messageId);

    function quoteDispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external view returns (uint256 fee);
}

contract HyperlaneReactive is AbstractReactive, AbstractCallback {
    event Trigger(bytes message);

    uint256 public constant TRIGGER_TOPIC_0 = 0x53a2e0b3dcf16cac9f71dfcb6c65d844af89dde99eda1fbb5396c1a39e8826ec;
    uint64 public constant GAS_LIMIT = 1000000;

    address public owner;
    IMailbox public mailbox;
    uint256 public chain_id;
    address public origin;

    constructor(
        IMailbox _mailbox,
        uint256 _chain_id,
        address _origin
    ) AbstractCallback(address(SERVICE_ADDR)) payable {
        owner = msg.sender;
        mailbox = _mailbox;
        chain_id = _chain_id;
        origin = _origin;
        if (!vm) {
            service.subscribe(
                chain_id,
                origin,
                TRIGGER_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                block.chainid,
                address(this),
                TRIGGER_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Not authorized');
        _;
    }

    function trigger(bytes calldata message) external onlyOwner {
        emit Trigger(message);
    }

    function send(bytes calldata message) external onlyOwner {
        _send(message);
    }

    function callback(address rvm_id, bytes calldata message) external authorizedSenderOnly rvmIdOnly(rvm_id) {
        _send(message);
    }

    function react(LogRecord calldata log) external vmOnly {
        bytes memory payload = abi.encodeWithSignature("callback(address,bytes)", address(0), log.data);
        emit Callback(block.chainid, address(this), GAS_LIMIT, payload);
    }

    function _send(bytes memory message) internal {
        bytes32 recipient = bytes32(uint256(uint160(origin)));
        uint256 fee = mailbox.quoteDispatch(uint32(chain_id), recipient, message);
        mailbox.dispatch{ value: fee }(uint32(chain_id), recipient, message);
    }
}
