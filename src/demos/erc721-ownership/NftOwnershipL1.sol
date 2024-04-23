// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

contract NftOwnershipL1 {
    event Request(
        address indexed token,
        uint256 indexed token_id
    );

    event Ownership(
        address indexed token,
        uint256 indexed token_id,
        address[] owners
    );

    address private owner;
    address private callback_sender;

    constructor(address _callback_sender) {
        owner = msg.sender;
        callback_sender = _callback_sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Unauthorized');
        _;
    }

    modifier onlyReactive() {
        if (callback_sender != address(0)) {
            require(msg.sender == callback_sender, 'Unauthorized');
        }
        _;
    }

    function request(
        address token,
        uint256 token_id
    ) external onlyOwner {
        emit Request(token, token_id);
    }

    function callback(
        address /* sender */,
        address token,
        uint256 token_id,
        address[] calldata owners
    ) external onlyReactive {
        emit Ownership(token, token_id, owners);
    }
}
