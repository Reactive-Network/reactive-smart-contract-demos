// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import "../../IReactive.sol";
import "../../AbstractReactive.sol";
import "../../ISubscriptionService.sol";

// Custom errors
error InvalidChainId();
error InvalidContract();
error InvalidEvent();

contract AutomatedPredictionReactive is IReactive, AbstractReactive {
    event BridgeEvent(
        uint256 indexed chainId,
        address indexed sourceContract,
        uint256 indexed predictionId,
        uint256 outcome,
        uint256 counter
    );

    // Topic for the PredictionResolved event
    // keccak256("PredictionResolved(uint256,uint256)")
    uint256 private constant PREDICTION_RESOLVED_TOPIC = 
        0xe0d11dcca65d89777e74a05aabfc99281a4c018644b33af1b397a7dbf5e2911b;

    uint256 public originChainId;
    uint256 public destinationChainId;
    uint64 private constant GAS_LIMIT = 1000000;
    address public predictionMarketContract;
    uint256 public counter;

    constructor(
        address _service,
        address _predictionMarketContract
    ) {
        originChainId = 11155111;
        destinationChainId = 11155111;
        predictionMarketContract = _predictionMarketContract;
        service = ISystemContract(payable(_service));

        // Subscribe to PredictionResolved events
        bytes memory payload = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            11155111,
            _predictionMarketContract,
            PREDICTION_RESOLVED_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result, ) = address(service).call(payload);
        vm = !subscription_result;
    }

    receive() external payable {}

    function react(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 /*topic_3*/,
        bytes calldata /*data*/,
        uint256 /* block_number */,
        uint256 /* op_code */
    ) external vmOnly {
        if (chain_id != originChainId) revert InvalidChainId();
        if (_contract != predictionMarketContract) revert InvalidContract();
        if (topic_0 != PREDICTION_RESOLVED_TOPIC) revert InvalidEvent();

        emit BridgeEvent(
            chain_id,
            _contract,
            topic_1, // predictionId
            topic_2, // outcome
            ++counter
        );

        // Decode the PredictionResolved event data
        uint256 predictionId = topic_1;

        // Prepare the distributeWinnings call
        bytes memory payload = abi.encodeWithSignature(
            "distributeWinnings(address,uint256)",
            address(0), // sender (will be replaced by ReactVM)
            predictionId
        );

        // Emit callback to trigger distributeWinnings on the destination chain
        emit Callback(
            destinationChainId,
            predictionMarketContract,
            GAS_LIMIT,
            payload
        );
    }

    // Methods for testing environment
    function pretendVm() external {
        vm = true;
    }

    function resetCounter() external {
        counter = 0;
    }

    function subscribe(
        uint256 _chainId,
        address _contract,
        uint256 topic_0
    ) external {
        service.subscribe(
            _chainId,
            _contract,
            topic_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    function unsubscribe(
        uint256 _chainId,
        address _contract,
        uint256 topic_0
    ) external {
        service.unsubscribe(
            _chainId,
            _contract,
            topic_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }
}