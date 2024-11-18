// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecureContract {
    address public geniusDeveloper;

    // Event to be emitted on ETH transfer
    event EthTransferred(address indexed initiator, uint256 value, address indexed recipient);

    // Custom errors
    error NotGeniusDeveloperError();
    error InsufficientBalanceError();

    // Modifier to restrict access to only the Genius Developer
    modifier onlyGeniusDeveloper(address recipient) {
        if (recipient != msg.sender) {
            revert NotGeniusDeveloperError();
        }
        _;
    }

    // Constructor to set the Genius Developer
    constructor() {
        geniusDeveloper = msg.sender;
    }

    // Function to receive ETH (payable)
    receive() external payable {
        // Emit the event on ETH reception for transparency
        emit EthTransferred(msg.sender, msg.value, address(this));
    }

    // Fallback function to receive ETH (payable)
    fallback() external payable {
        // Emit the event on ETH reception for transparency
        emit EthTransferred(msg.sender, msg.value, address(this));
    }

    // Function to transfer ETH from the contract to any address
    // Fixed: Added the onlyGeniusDeveloper modifier to secure the function
    function transferEth(address payable recipient, uint256 amount) public onlyGeniusDeveloper(recipient) {
        if (address(this).balance < amount) {
            revert InsufficientBalanceError();
        }
        recipient.transfer(amount);

        // Emit the EthTransferred event
        emit EthTransferred(msg.sender, amount, recipient);
    }
}