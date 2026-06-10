// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";

contract CronDemo is AbstractReactive {

    error UnsupportedInterval(uint256 interval);

    address internal constant LEGACY_SYSTEM_ADDR = 0x0000000000000000000000000000000000fffFfF;

    uint256 internal constant CRON1_TOPIC_0 = 0xf02d6ea5c22a71cffe930a4523fcb4f129be6c804db50e4202fb4e0b07ccb514;
    uint256 internal constant CRON10_TOPIC_0 = 0x04463f7c1651e6b9774d7f85c85bb94654e3c46ca79b0c16fb16d4183307b687;
    uint256 internal constant CRON100_TOPIC_0 = 0xb49937fb8970e19fd46d48f7e3fb00d659deac0347f79cd7cb542f0fc1503c70;
    uint256 internal constant CRON1000_TOPIC_0 = 0xe20b31294d84c3661ddc8f423abb9c70310d0cf172aa2714ead78029b325e3f4;
    uint256 internal constant CRON10000_TOPIC_0 = 0xd214e1d84db704ed42d37f538ea9bf71e44ba28bc1cc088b2f5deca654677a56;

    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    uint256 public immutable _cronInterval;
    uint256 public immutable _cronTopic0;

    constructor(uint256 interval_) payable {
        _cronInterval = interval_;
        _cronTopic0 = _topicFor(interval_);

        SYSTEM.subscribe(
            block.chainid,
            LEGACY_SYSTEM_ADDR,
            _cronTopic0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    function react(LogRecord calldata log_) external onlySystem {
        if (log_.topic0 == _cronTopic0) {
            SYSTEM.requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0({
                chainId: block.chainid,
                recipient: address(this),
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: abi.encodeWithSignature("callback(address)", address(0))
            }));
        }
    }

    function _topicFor(uint256 interval_) internal pure returns (uint256 topic0_) {
        if (interval_ == 1) return CRON1_TOPIC_0;
        if (interval_ == 10) return CRON10_TOPIC_0;
        if (interval_ == 100) return CRON100_TOPIC_0;
        if (interval_ == 1000) return CRON1000_TOPIC_0;
        if (interval_ == 10000) return CRON10000_TOPIC_0;
        revert UnsupportedInterval(interval_);
    }
}
