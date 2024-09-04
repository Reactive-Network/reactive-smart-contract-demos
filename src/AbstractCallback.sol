// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import './IPayable.sol';
import './AbstractPayer.sol';

abstract contract AbstractCallback is AbstractPayer {
    address internal rvm_id;

    constructor(address _callback_sender) {
        rvm_id = msg.sender;
        vendor = IPayable(payable(_callback_sender));
    }

    modifier rvmIdOnly(address _rvm_id) {
        require(rvm_id == address(0) || rvm_id == _rvm_id, 'Authorized RVM ID only');
        _;
    }
}
