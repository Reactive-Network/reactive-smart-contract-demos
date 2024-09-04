// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../AbstractCallback.sol';

contract NftOwnershipL1 is AbstractCallback {
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

    constructor(address _callback_sender) AbstractCallback(_callback_sender) payable {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Unauthorized');
        _;
    }

    receive() external payable {}

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
    ) external authorizedSenderOnly {
        emit Ownership(token, token_id, owners);
    }
}
