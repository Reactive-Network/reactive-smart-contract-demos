// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';

contract TokenTurnoverL1 is AbstractCallback {
    event Request(
        address indexed token
    );

    event Turnover(
        address indexed token,
        uint256 indexed turnover
    );

    address private owner;

    constructor(address _callback_sender) AbstractCallback(_callback_sender) payable {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Unauthorized');
        _;
    }

    function request(
        address token
    ) external onlyOwner {
        emit Request(token);
    }

    function callback(
        address /* sender */,
        address token,
        uint256 turnover
    ) external authorizedSenderOnly {
        emit Turnover(token, turnover);
    }
}
