// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

contract TokenTurnoverL1 {
    event Request(
        address indexed token
    );

    event Turnover(
        address indexed token,
        uint256 indexed turnover
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
        address token
    ) external onlyOwner {
        emit Request(token);
    }

    function callback(
        address /* sender */,
        address token,
        uint256 turnover
    ) external onlyReactive {
        emit Turnover(token, turnover);
    }
}
