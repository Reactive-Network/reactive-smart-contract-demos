// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "../../../lib/reactive-lib/src/interfaces/IReactive.sol";
import "../../../lib/reactive-lib/src/abstract-base/AbstractPausableReactive.sol";

contract AaveLiquidationProtectionReactive is IReactive, AbstractPausableReactive {

    event HealthFactorChecked(uint256 currentHealthFactor, uint256 threshold);
    event Done();

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant POSITION_PROTECTED_TOPIC_0 = 0xc36075e656a1ae37433e843be9f03b48aa277aa3174cadf877d8d58fe686215d;
    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    // State specific to ReactVM instance of the contract.

    bool private triggered;
    address private lendingPool;
    address private protectionManager;
    address private user;
    uint256 private healthFactorThreshold;
    uint256 private targetHealthFactor;
    uint256 public cronTopic;

    constructor(
        address _lendingPool,
        address _protectionManager,
        address _service,
        uint256 _cronTopic,
        address _user,
        uint256 _healthFactorThreshold,
        uint256 _targetHealthFactor
    ) payable {
        service = ISystemContract(payable(_service));
        triggered = false;
        lendingPool = _lendingPool;
        protectionManager = _protectionManager;
        user = _user;
        healthFactorThreshold = _healthFactorThreshold;
        targetHealthFactor = _targetHealthFactor;
        cronTopic = _cronTopic;
        if (!vm) {
            service.subscribe(
                block.chainid,
                address(service),
                cronTopic,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                protectionManager,
                POSITION_PROTECTED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    function getPausableSubscriptions() internal view override returns (Subscription[] memory) {
        Subscription[] memory result = new Subscription[](1);
        result[0] = Subscription(
            block.chainid,
            address(service),
            cronTopic,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return result;
    }

    // Methods specific to ReactVM instance of the contract.

    function react(LogRecord calldata log) external vmOnly {
        if (log.topic_0 == cronTopic) {
            if (triggered) {
                return;
            }
            bytes memory payload = abi.encodeWithSignature(
                "protectPosition(address,address,address,uint256,uint256)",
                address(0),
                user,
                lendingPool,
                targetHealthFactor,
                healthFactorThreshold
            );
            triggered = true;
            emit Callback(
                SEPOLIA_CHAIN_ID,
                protectionManager,
                CALLBACK_GAS_LIMIT,
                payload
            );
        } else if (log._contract == protectionManager && log.topic_0 == POSITION_PROTECTED_TOPIC_0) {
            triggered = false;
            emit Done();
        }
    }
}