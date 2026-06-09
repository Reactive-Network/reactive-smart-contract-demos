// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";

/**
 * A basic cron demo. Subscribes to one of the network's fixed-interval cron
 * events and requests a callback to itself on every tick.
 */

contract BasicCronContract is AbstractReactive {
    /// @notice Supported cron intervals, expressed in blocks.
    enum CronInterval { CRON1, CRON10, CRON100, CRON1000, CRON10000, CRON100000 }

    /// @notice Hardcoded address of the network's legacy system contract.
    address internal constant CRON_ADDR = 0x0000000000000000000000000000000000FfFFff;

    /// @notice `topic0` of the `Cron1()` event (every block).
    uint256 internal constant CRON1_TOPIC_0 = 0xf02d6ea5c22a71cffe930a4523fcb4f129be6c804db50e4202fb4e0b07ccb514;

    /// @notice `topic0` of the `Cron10()` event (every 10 blocks).
    uint256 internal constant CRON10_TOPIC_0 = 0x04463f7c1651e6b9774d7f85c85bb94654e3c46ca79b0c16fb16d4183307b687;

    /// @notice `topic0` of the `Cron100()` event (every 100 blocks).
    uint256 internal constant CRON100_TOPIC_0 = 0xb49937fb8970e19fd46d48f7e3fb00d659deac0347f79cd7cb542f0fc1503c70;

    /// @notice `topic0` of the `Cron1000()` event (every 1,000 blocks).
    uint256 internal constant CRON1000_TOPIC_0 = 0xe20b31294d84c3661ddc8f423abb9c70310d0cf172aa2714ead78029b325e3f4;

    /// @notice `topic0` of the `Cron10000()` event (every 10,000 blocks).
    uint256 internal constant CRON10000_TOPIC_0 = 0xd214e1d84db704ed42d37f538ea9bf71e44ba28bc1cc088b2f5deca654677a56;

    /// @notice `topic0` of the `Cron100000()` event (every 100,000 blocks).
    uint256 internal constant CRON100000_TOPIC_0 = 0x4c7293c04ee4490432bb600702ca2d0f56dd06e6bbe053ab1d8dd225d2efc403;

    /// @notice Gas limit for the requested callback.
    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    /// @notice The cron `topic0` this contract is subscribed to.
    uint256 public immutable _cronTopic0;

    /// @notice Block number of the last cron tick received.
    uint256 public _lastCronBlock;

    /// @param interval_ Desired cron interval. The matching topic is resolved internally.
    constructor(CronInterval interval_) payable {
        _cronTopic0 = _topicFor(interval_);

        SYSTEM.subscribe(
            block.chainid,
            CRON_ADDR,
            _cronTopic0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    /// @inheritdoc IReactive
    function react(LogRecord calldata log_) external onlySystem {
        if (log_.topic0 == _cronTopic0) {
            _lastCronBlock = block.number;

            SYSTEM.requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0({
                chainId: block.chainid,
                recipient: address(this),
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: abi.encodeWithSignature("callback(address)", address(0))
            }));
        }
    }

    /// @notice Resolves a cron interval to its corresponding event `topic0`.
    /// @param interval_ Desired cron interval.
    /// @return topic0_ Matching cron event `topic0`.
    function _topicFor(CronInterval interval_) internal pure returns (uint256 topic0_) {
        if (interval_ == CronInterval.CRON1) return CRON1_TOPIC_0;
        if (interval_ == CronInterval.CRON10) return CRON10_TOPIC_0;
        if (interval_ == CronInterval.CRON100) return CRON100_TOPIC_0;
        if (interval_ == CronInterval.CRON1000) return CRON1000_TOPIC_0;
        if (interval_ == CronInterval.CRON10000) return CRON10000_TOPIC_0;
        return CRON100000_TOPIC_0; // CronInterval.CRON100000
    }
}
