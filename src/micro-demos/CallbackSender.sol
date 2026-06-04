// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";

/**
 * A simple contract for sending callbacks.
 */
contract CallbackSender is AbstractReactive {
    /// @notice Indicates that the method is not supported.
    error NotSupported();

    /// @notice Sepolia chain ID.
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    /// @notice Contract deployer's address.
    address public immutable _OWNER;

    /// @notice Counterparty's adress.
    address public _counterparty;

    constructor() payable {
        _OWNER = msg.sender;
    }

    /// @notice Changes the callback recipient's address.
    /// @param counterparty_ New callback recipient's address.
    function setCounterParty(address counterparty_) external {
        require(msg.sender == _OWNER);
        _counterparty = counterparty_;
    }

    /// @notice Sends a callback to the recipient contract.
    function ping() external {
        require(_counterparty != address(0));

        bytes memory payload = abi.encodeWithSignature("pong(address,address)", address(0), msg.sender);
        
        SYSTEM.requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0({
            chainId: SEPOLIA_CHAIN_ID,
            recipient: _counterparty,
            gasLimit: 1000000,
            payload: payload
        }));
    }

    /// @inheritdoc IReactive
    function react(LogRecord memory /* log_ */) external view onlySystem {
        revert NotSupported();
    }
}
