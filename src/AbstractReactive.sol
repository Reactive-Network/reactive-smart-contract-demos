// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import './IReactive.sol';
import './IPayable.sol';
import './AbstractPayer.sol';
import './ISystemContract.sol';

abstract contract AbstractReactive is IReactive, AbstractPayer {
    uint256 internal constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;
    ISystemContract internal constant SERVICE_ADDR = ISystemContract(payable(0x0000000000000000000000000000000000fffFfF));

    /**
     * Indicates whether this is a ReactVM instance of the contract.
     */
    bool internal vm;

    ISystemContract internal service;

    constructor() {
        vendor = service = SERVICE_ADDR;
    }

    modifier rnOnly() {
        // require(!vm, 'Reactive Network only');
        _;
    }

    modifier vmOnly() {
        // require(vm, 'VM only');
        _;
    }

    modifier sysConOnly() {
        require(msg.sender == address(service), 'System contract only');
        _;
    }

    function detectVm() internal {
        bytes memory payload = abi.encodeWithSignature("ping()");
        (bool result,) = address(service).call(payload);
        vm = !result;
    }
}
