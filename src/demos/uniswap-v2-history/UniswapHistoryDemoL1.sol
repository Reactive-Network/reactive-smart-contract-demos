// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';

contract UniswapHistoryDemoL1 is AbstractCallback {
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

    constructor(address _callback_sender) AbstractCallback(_callback_sender) payable {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Unauthorized');
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
    ) external authorizedSenderOnly {
        emit ReSync(pair, block_number, reserve0, reserve1);
    }
}
