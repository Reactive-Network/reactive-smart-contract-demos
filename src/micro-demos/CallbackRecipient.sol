// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { AbstractCallback } from "@reactive/src/base/AbstractCallback.sol";

/**
 * A simple contract for receiving callbacks.
 */
contract CallbackRecipient is AbstractCallback {
    /// @param ping_ Address that called the `ping()` method on the reactive side.
    event Pong(address indexed ping_);

    /// @param proxy_ Callback proxy address.
    /// @param reactive_ Address of the reactive contract.
    constructor(IPayable proxy_, address reactive_) payable AbstractCallback(proxy_, reactive_) {
    }

    /// @notice Callback method.
    /// @param reactive_ Reactive contract's address for sender authentication.
    /// @param ping_ Address that called the `ping()` method on the reactive side.
    function pong(address reactive_, address ping_) external onlyServiceProvider onlyCallbackSender(reactive_) {
        emit Pong(ping_);
    }
}
