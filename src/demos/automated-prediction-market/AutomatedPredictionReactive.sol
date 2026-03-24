// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import "../../../lib/reactive-lib/src/interfaces/IReactive.sol";
import "../../../lib/reactive-lib/src/abstract-base/AbstractReactive.sol";

/**
 * @title AutomatedPredictionReactive
 * @notice Reactive contract that listens for PredictionResolved events on Sepolia
 *         and triggers winnings distribution via callback
 * @dev Deployed on the Reactive Network; paired with AutomatedPredictionMarket on Sepolia
 */
contract AutomatedPredictionReactive is IReactive, AbstractReactive {
    event BridgeEvent(
        uint256 indexed chainId,
        address indexed sourceContract,
        uint256 indexed predictionId,
        uint256 outcome,
        uint256 counter
    );

    // keccak256("PredictionResolved(uint256,uint256)")
    uint256 private constant PREDICTION_RESOLVED_TOPIC_0 =
        0xe0d11dcca65d89777e74a05aabfc99281a4c018644b33af1b397a7dbf5e2911b;

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    address public immutable predictionMarketContract;
    uint256 public counter;

    constructor(address _predictionMarketContract) payable {
        predictionMarketContract = _predictionMarketContract;

        if (!vm) {
            // Subscribe to PredictionResolved events from the callback contract on Sepolia
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                _predictionMarketContract,
                PREDICTION_RESOLVED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    /**
     * @notice Main reaction function — called by the Reactive Network when a subscribed event fires
     * @dev Decodes the PredictionResolved event and emits a Callback to distribute winnings
     */
    function react(LogRecord calldata log) external vmOnly {
        // Only handle PredictionResolved events from the prediction market contract
        if (log._contract != predictionMarketContract) {
            return;
        }
        if (log.topic_0 != PREDICTION_RESOLVED_TOPIC_0) {
            return;
        }

        uint256 predictionId = log.topic_1;
        uint256 outcome = log.topic_2;

        emit BridgeEvent(log.chain_id, log._contract, predictionId, outcome, ++counter);

        // Trigger distributeWinnings on Sepolia
        bytes memory payload = abi.encodeWithSignature(
            "distributeWinnings(address,uint256)",
            address(0), // sender — replaced by Reactive Network
            predictionId
        );

        emit Callback(SEPOLIA_CHAIN_ID, predictionMarketContract, CALLBACK_GAS_LIMIT, payload);
    }
}
