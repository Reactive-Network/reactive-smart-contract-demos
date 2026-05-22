// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";

/**
 * A simple reactive contract subscribed to Sepolia transfers.
 */
contract Xfers is AbstractReactive {
    /// @notice Emitted whenever a new transfer is detected.
    /// @param token_ ERC20 token contract address.
    /// @param volume_ Transfer volume.
    event Turnover(
        address indexed token_,
        uint256 indexed volume_
    );

    /// @notice A struct for decoding the payload of `Transfer()` events.
    struct Transfer {
        uint256 tokens;
    }

    /// @notice Sepolia chain ID.
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    /// @notice `topic0` for `Transfer()` events.
    uint256 private constant ERC20_TRANSFER_TOPIC_0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    /// @notice Event signature of the `Ping()` event.
    uint256 public constant PING_TOPIC_0 = 0xca6e822df923f741dfe968d15d80a18abd25bd1e748bcb9ad81fea5bbb7386af;

    /// @notice Contract deployer's address.
    address public immutable _OWNER;

    /// @notice Event to catch before unsubscribing.
    uint256 public _limit;

    /// @notice Last transaction hash intercepted.
    uint256 public _lastTxHash;

    /// @notice Block number of the last reactive transaction received.
    uint256 public _lastReactBlockNumber;

    /// @notice Mapping of ERC20 token contract addresses to their turnover so far.
    mapping(address => uint256) public _turnovers;

    /// @param limit_ Initial limit on the number fo events to catch.
    constructor(uint256 limit_) payable {
        _OWNER = msg.sender;
        _limit = limit_;
        _sub();
    }

    /// @notice Updates the event limit to the specified value. Subs or unsubs accordingly.
    /// @param limit_ New value of the event limit.
    function updateLimit(uint256 limit_) external payable {
        require(msg.sender == _OWNER);

        _limit = limit_;

        if (limit_ == 0) {
            _unsub();
        } else {
            _coverDebt();
            _sub();
        }
    }

    /// @inheritdoc IReactive
    function react(LogRecord memory log_) external onlySystem {
        if (log_.opCode == 3) {
            _lastTxHash = log_.txHash;
            _lastReactBlockNumber = block.number;

            Transfer memory xfer = abi.decode(log_.data, ( Transfer ));
            _turnovers[log_.contractAddress] += xfer.tokens;

            emit Turnover(log_.contractAddress, xfer.tokens);

            if (--_limit == 0) {
                _unsub();
            }
        }
    }

    /// @notice Subscribes to `Transfer()` events in Sepolia.
    function _sub() internal {
        SYSTEM.subscribe(
            SEPOLIA_CHAIN_ID,
            address(0),
            ERC20_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    /// @notice Removes the event subscription.
    function _unsub() internal {
        SYSTEM.unsubscribe(
            SEPOLIA_CHAIN_ID,
            address(0),
            ERC20_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }
}
