// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";

/**
 * A simple reactive contract subscribed to its own events.
 */
contract PingPong is AbstractReactive {
    /// @notice An event that the contract subscribes to.
    event Ping();

    /// @param txHash_ Transaction hash of the original transaction.
    event Pong(uint256 indexed txHash_);

    /// @notice Event signature of the `Ping()` event.
    uint256 public constant PING_TOPIC_0 = 0xca6e822df923f741dfe968d15d80a18abd25bd1e748bcb9ad81fea5bbb7386af;

    /// @notice Last transaction hash intercepted.
    uint256 public _lastTxHash;

    /// @notice Block number of the last reactive transaction received.
    uint256 public _lastReactBlockNumber;

    constructor() payable {
        SYSTEM.subscribe(
            block.chainid,
            address(this),
            PING_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    /// @notice Causes the contract to emit the event it's subscribed to.
    function ping() external {
        emit Ping();
    }

    /// @inheritdoc IReactive
    function react(LogRecord memory log_) external onlySystem {
        _lastTxHash = log_.txHash;
        _lastReactBlockNumber = block.number;

        emit Pong(log_.txHash);
    }
}
