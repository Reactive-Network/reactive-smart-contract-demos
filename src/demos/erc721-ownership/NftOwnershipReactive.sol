// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../IReactive.sol';
import '../../ISubscriptionService.sol';

contract NftOwnershipReactive is IReactive {
    event OwnershipTransfer(
        address indexed token,
        uint256 indexed token_id,
        address indexed owner
    );

    uint256 private constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    uint256 private constant ERC721_TRANSFER_TOPIC_0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    uint256 private constant L1_RQ_TOPIC_0 = 0xe31c60e37ab1301f69f01b436a1d13486e6c16cc22c888a08c0e64a39230b6ac;

    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    /**
     * Indicates whether this is the instance of the contract deployed to ReactVM.
     */
    bool private vm;

    // State specific to reactive network instance

    address private owner;
    bool private paused;
    ISubscriptionService private service;

    // State specific to ReactVM instance of the contract

    mapping(address => mapping(uint256 => address[])) private ownership;
    address private l1;

    constructor(
        address service_address,
        address _l1
    ) {
        owner = msg.sender;
        paused = false;
        l1 = _l1;
        service = ISubscriptionService(service_address);
        bytes memory payload = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            SEPOLIA_CHAIN_ID,
            0,
            ERC721_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result,) = address(service).call(payload);
        if (!subscription_result) {
            vm = true;
        }
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
        if (!subscription_result_2) {
            vm = true;
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Unauthorized');
        _;
    }

    modifier rnOnly() {
        require(!vm, 'Reactive Network only');
        _;
    }

    modifier vmOnly() {
        // TODO: fix the assertion after testing.
        //require(vm, 'VM only');
        _;
    }

    // Methods specific to reactive network instance

    function pause() external rnOnly onlyOwner {
        require(!paused, 'Paused');
        service.unsubscribe(
            SEPOLIA_CHAIN_ID,
            address(0),
            ERC721_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        paused = true;
    }

    function resume() external rnOnly onlyOwner {
        require(paused, 'Not paused');
        service.subscribe(
            SEPOLIA_CHAIN_ID,
            address(0),
            ERC721_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        paused = false;
    }

    // Methods specific to ReactVM instance

    function react(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes calldata /* data */,
        uint256 /* block_number */,
        uint256 op_code
    ) external vmOnly {
        if (topic_0 == ERC721_TRANSFER_TOPIC_0) {
            if (op_code == 4) {
                ownership[_contract][topic_3].push(address(uint160(topic_2)));
                emit OwnershipTransfer(_contract, topic_3, address(uint160(topic_2)));
            }
        } else {
            bytes memory payload = abi.encodeWithSignature(
                "callback(address,address,uint256,address[])",
                address(0),
                address(uint160(topic_1)),
                topic_2,
                owners(address(uint160(topic_1)), topic_2)
            );
            emit Callback(chain_id, l1, CALLBACK_GAS_LIMIT, payload);
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
