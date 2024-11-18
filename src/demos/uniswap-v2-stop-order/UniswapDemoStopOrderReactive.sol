// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import "../../IReactive.sol";
import "../../AbstractReactive.sol";
import "../../ISubscriptionService.sol";

    struct Reserves {
        uint112 reserve0;
        uint112 reserve1;
    }

contract UniswapDemoStopOrderReactive is IReactive, AbstractReactive {
    event Subscribed(
        address indexed service_address,
        address indexed _contract,
        uint256 indexed topic_0
    );

    event VM();

    event AboveThreshold(
        uint112 indexed reserve0,
        uint112 indexed reserve1,
        uint256 coefficient,
        uint256 threshold
    );

    event CallbackSent();

    event Done();

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    uint256 private constant UNISWAP_V2_SYNC_TOPIC_0 = 0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1;
    uint256 private constant STOP_ORDER_STOP_TOPIC_0 = 0x9996f0dd09556ca972123b22cf9f75c3765bc699a1336a85286c7cb8b9889c6b;

    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    // State specific to ReactVM instance of the contract.

    bool private triggered;
    bool private done;
    address private pair;
    address private stop_order;
    address private client;
    bool private token0;
    uint256 private coefficient;
    uint256 private threshold;

    constructor(
        address _pair,
        address _stop_order,
        address _client,
        bool _token0,
        uint256 _coefficient,
        uint256 _threshold
    ) {
        triggered = false;
        done = false;
        pair = _pair;
        bytes memory payload = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            pair,
            UNISWAP_V2_SYNC_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result,) = address(service).call(payload);
        if (!subscription_result) {
            vm = true;
            emit VM();
        } else {
            emit Subscribed(address(service), pair, UNISWAP_V2_SYNC_TOPIC_0);
        }
        stop_order = _stop_order;
        bytes memory payload_2 = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            stop_order,
            STOP_ORDER_STOP_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result_2,) = address(service).call(payload_2);
        if (!subscription_result_2) {
            vm = true;
            emit VM();
        } else {
            emit Subscribed(address(service), stop_order, STOP_ORDER_STOP_TOPIC_0);
        }
        client = _client;
        token0 = _token0;
        coefficient = _coefficient;
        threshold = _threshold;
    }

    receive() external payable {}

    // Methods specific to ReactVM instance of the contract.

    function react(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 /* topic_3 */,
        bytes calldata data,
        uint256 /* block_number */,
        uint256 /* op_code */
    ) external vmOnly {
        // TODO: Support for multiple dynamic orders? Not viable until we have dynamic subscriptions.
        // TODO: Unsubscribe on completion.
        assert(!done);
        if (_contract == stop_order) {
            // TODO: Practically speaking, it's broken, because we also need to check the transfer direction.
            //       For the purposes of the demo, I'm just going to ignore that complication.
            if (
                triggered &&
                topic_0 == STOP_ORDER_STOP_TOPIC_0 &&
                topic_1 == uint256(uint160(pair)) &&
                topic_2 == uint256(uint160(client))
            ) {
                done = true;
                emit Done();
            }
        } else {
            Reserves memory sync = abi.decode(data, ( Reserves ));
            if (below_threshold(sync) && !triggered) {
                emit CallbackSent();
                bytes memory payload = abi.encodeWithSignature(
                    "stop(address,address,address,bool,uint256,uint256)",
                    address(0),
                    pair,
                    client,
                    token0,
                    coefficient,
                    threshold
                );
                triggered = true;
                emit Callback(chain_id, stop_order, CALLBACK_GAS_LIMIT, payload);
            }
        }
    }

    function below_threshold(Reserves memory sync) internal view returns (bool) {
        if (token0) {
            return (sync.reserve1 * coefficient) / sync.reserve0 <= threshold;
        } else {
            return (sync.reserve0 * coefficient) / sync.reserve1 <= threshold;
        }
    }
}
