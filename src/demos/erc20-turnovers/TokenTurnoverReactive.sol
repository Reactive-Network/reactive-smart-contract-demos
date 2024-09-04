// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../IReactive.sol';
import '../../AbstractPausableReactive.sol';
import '../../ISubscriptionService.sol';

    struct Transfer {
        uint256 tokens;
    }

contract TokenTurnoverReactive is IReactive, AbstractPausableReactive {
    event Turnover(
        address indexed token,
        uint256 indexed volume
    );

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    uint256 private constant ERC20_TRANSFER_TOPIC_0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    uint256 private constant L1_RQ_TOPIC_0 = 0x9a26a1f9def08abe958f09f08b27ca5d3dcc90dc0bd84ac65a66e096560f3071;

    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    // State specific to ReactVM instance of the contract.

    mapping(address => uint256) private turnovers;
    address private l1;

    constructor(
        address _l1
    ) {
        paused = false;
        owner = msg.sender;
        l1 = _l1;
        bytes memory payload = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            0,
            0,
            ERC20_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result,) = address(service).call(payload);
        vm = !subscription_result;
        bytes memory payload_2 = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            l1,
            L1_RQ_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result_2,) = address(service).call(payload_2);
        vm = !subscription_result_2;
    }

    receive() external payable {}

    function getPausableSubscriptions() override internal pure returns (Subscription[] memory) {
        Subscription[] memory result = new Subscription[](1);
        result[0] = Subscription(
            SEPOLIA_CHAIN_ID,
            address(0),
            ERC20_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return result;
    }

    // Methods specific to ReactVM instance of the contract

    function react(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 /* topic_2 */,
        uint256 /* topic_3 */,
        bytes calldata data,
        uint256 /* block_number */,
        uint256 op_code
    ) external vmOnly {
        // Note that we cannot directly check the `paused` variable, because the state of the contract
        // in reactive network is not shared with ReactVM state.
        if (topic_0 == ERC20_TRANSFER_TOPIC_0) {
            if (op_code == 3) {
                Transfer memory xfer = abi.decode(data, ( Transfer ));
                turnovers[_contract] += xfer.tokens;
                emit Turnover(_contract, xfer.tokens);
            }
        } else {
            bytes memory payload = abi.encodeWithSignature(
                "callback(address,address,uint256)",
                address(0),
                address(uint160(topic_1)),
                turnover(address(uint160(topic_1)))
            );
            emit Callback(chain_id, l1, CALLBACK_GAS_LIMIT, payload);
        }
    }

    function turnover(address token) internal view returns (uint256) {
        return turnovers[token];
    }
}
