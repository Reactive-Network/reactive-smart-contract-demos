// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

contract HyperlaneOrigin {
    event Trigger(bytes message);

    event Received(
        uint32 indexed chain_id,
        address indexed sender,
        bytes message
    );

    address public owner;
    address public mailbox;

    constructor(address _mailbox) {
        owner = msg.sender;
        mailbox = _mailbox;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Not authorized');
        _;
    }

    modifier onlyMailbox() {
        require(msg.sender == mailbox, 'Not authorized');
        _;
    }

    function trigger(bytes calldata message) external onlyOwner {
        emit Trigger(message);
    }

    function handle(
        uint32 chain_id,
        bytes32 sender,
        bytes calldata message
    ) external payable onlyMailbox {
        emit Received(chain_id, address(uint160(uint256(sender))), message);
    }
}
