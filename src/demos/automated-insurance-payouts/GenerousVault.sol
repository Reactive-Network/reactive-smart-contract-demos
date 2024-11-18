// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../AbstractCallback.sol";

contract GenerousVault is AbstractCallback {
    address public deployingAddress;
    address public reactiveAddress;

    event EthTransferred(address indexed initiator, uint256 value, address indexed recipient);

    // Custom errors
    error UnauthorizedAccessError();
    error InsufficientBalanceError();

    modifier onlyAuthorized() {
        if (msg.sender != reactiveAddress && msg.sender != deployingAddress) {
            revert UnauthorizedAccessError();
        }
        _;
    }

    constructor(address _callback_Sender) AbstractCallback(_callback_Sender) payable {
        deployingAddress = msg.sender;
        reactiveAddress = 0x356bc9241f9b004323fE0Fe75C3d75DD946cF15c;
    }

    receive() external payable {
        emit EthTransferred(msg.sender, msg.value, address(this));
    }

    fallback() external payable {
        emit EthTransferred(msg.sender, msg.value, address(this));
    }

    function payout(address /* RVM ID */, address payable policyholder, uint256 compensation) public onlyAuthorized() {
        if (address(this).balance < compensation) {
            revert InsufficientBalanceError();
        }
        policyholder.transfer(compensation);

        emit EthTransferred(msg.sender, compensation, policyholder);
    }
}