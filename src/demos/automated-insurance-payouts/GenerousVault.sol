// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "../../AbstractCallback.sol";


contract GenerousVault is AbstractCallback {
    address public deployingAddress;
    address public reactiveAddress;

 
    event EthTransferred(address indexed initiator, uint256 value, address indexed recipient);

    modifier onlyAuthorized() {
        require(msg.sender == reactiveAddress || msg.sender == deployingAddress, "Access restricted to authorized addresses");
        _;
    }

    constructor(address _callback_sender) AbstractCallback(_callback_sender) payable {
        deployingAddress = msg.sender;
        reactiveAddress = 0x356bc9241f9b004323fE0Fe75C3d75DD946cF15c;
    }


    receive() external payable {
        emit EthTransferred(msg.sender, msg.value, address(this));
    }

    fallback() external payable {
        emit EthTransferred(msg.sender, msg.value, address(this));
    }

    function payout(address /* RVM ID */, address payable policyholder, uint256 compensation) onlyAuthorized() public {
        require(address(this).balance >= compensation, "Insufficient ETH balance in GenerousVault");
        policyholder.transfer(compensation);

        emit EthTransferred(msg.sender, compensation, policyholder);
    }
}
