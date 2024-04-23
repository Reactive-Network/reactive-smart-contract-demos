// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

contract UniswapHistoryDemoL1 {
    event RequestReSync(
        address indexed pair,
        uint256 indexed block_number
    );

    event ReSync(
        address indexed pair,
        uint256 indexed block_number,
        uint112 reserve0,
        uint112 reserve1
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
        address pair,
        uint256 block_number
    ) external onlyOwner {
        emit RequestReSync(pair, block_number);
    }

    function resync(
        address /* sender */,
        address pair,
        uint256 block_number,
        uint112 reserve0,
        uint112 reserve1
    ) external onlyReactive {
        emit ReSync(pair, block_number, reserve0, reserve1);
    }
}
