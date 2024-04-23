// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

contract BasicDemoL1Contract {
    event Received(
        address indexed origin,
        address indexed sender,
        uint256 indexed value
    );

    receive() external payable {
        emit Received(
            tx.origin,
            msg.sender,
            msg.value
        );
        payable(tx.origin).transfer(msg.value);
    }
}
