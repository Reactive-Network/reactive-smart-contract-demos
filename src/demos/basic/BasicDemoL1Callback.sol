// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

contract BasicDemoL1Callback {
    event CallbackReceived(
        address indexed origin,
        address indexed sender,
        address indexed reactive_sender
    );

    function callback(address sender) external {
        emit CallbackReceived(
            tx.origin,
            msg.sender,
            sender
        );
    }
}
