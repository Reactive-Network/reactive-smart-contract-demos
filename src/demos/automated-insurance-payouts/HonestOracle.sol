// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HonestOracle {
    event TransactionEvent(address indexed sender, uint256 indexed amount);

    function emitEvent(address _sender, uint256 _amount) external {
        emit TransactionEvent(_sender, _amount);
    }
}
