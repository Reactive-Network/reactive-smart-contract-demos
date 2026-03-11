// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/interfaces/IReactive.sol';
import '../../../lib/reactive-lib/src/abstract-base/AbstractPausableReactive.sol';

contract NftOwnershipReactive is IReactive, AbstractPausableReactive {
    event OwnershipTransfer(
        address indexed token,
        uint256 indexed token_id,
        address indexed owner
    );

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant ERC721_TRANSFER_TOPIC_0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    uint256 private constant L1_RQ_TOPIC_0 = 0xe31c60e37ab1301f69f01b436a1d13486e6c16cc22c888a08c0e64a39230b6ac;
    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    // State specific to ReactVM instance of the contract
    mapping(address => mapping(uint256 => address[])) private ownership;
    address private l1;

    constructor(address _l1) payable {
        owner = msg.sender;
        paused = false;
        l1 = _l1;

        if (!vm) {
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                address(0),
                ERC721_TRANSFER_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                SEPOLIA_CHAIN_ID,
                l1,
                L1_RQ_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }


    function getPausableSubscriptions() internal pure override returns (Subscription[] memory) {
        Subscription[] memory result = new Subscription[](1);
        result[0] = Subscription(
            SEPOLIA_CHAIN_ID,
            address(0),
            ERC721_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return result;
    }

    // Methods specific to ReactVM instance
    function react(LogRecord calldata log) external vmOnly {
        if (log.topic_0 == ERC721_TRANSFER_TOPIC_0) {
            if (log.op_code == 4) {
                ownership[log._contract][log.topic_3].push(address(uint160(log.topic_2)));
                emit OwnershipTransfer(log._contract, log.topic_3, address(uint160(log.topic_2)));
            }
        } else {
            bytes memory payload = abi.encodeWithSignature(
                "callback(address,address,uint256,address[])",
                address(0),
                address(uint160(log.topic_1)),
                log.topic_2,
                owners(address(uint160(log.topic_1)), log.topic_2)
            );
            emit Callback(log.chain_id, l1, CALLBACK_GAS_LIMIT, payload);
        }
    }

    function owners(address _contract, uint256 token_id) internal view returns (address[] memory) {
        uint256 length = ownership[_contract][token_id].length;
        address[] memory result = new address[](length);

        for (uint256 ix = 0; ix != length; ++ix) {
            result[ix] = ownership[_contract][token_id][ix];
        }

        return result;
    }
}
