// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

interface IPayer {
    // @dev Make sure to check the msg.sender
    function pay(uint256 amount) external;
}
