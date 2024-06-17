# Basics Of Reactive Smart Contracts

Reactive smart contracts run on a standard EVM, and can be written in any EVM-compatible language, although the ABIs are tailored towards using Solidity in particular. Their novel capabilities are provided by reactive nodes and a specialized pre-deployed system contract.

## Special Considerations

The reactive contracts are deployed simultaneously to the main reactive network and to the private ReactVM subnet. The copy deployed to the main network can be interacted with by EOA's, and can, in turn, interact with the system contract to manage subscriptions. The copy deployed to ReactVM is used to process incoming events from origin chain contracts. EOA's cannot interact with this copy.

The two copies of the contract **DO NOT** share the state, and cannot interact directly. Since both copies use the same bytecode, it's recommended to identify the deployment target in constructor, and guard your methods accordingly. You can determine whether the contract is being deployed to ReactVM by interacting with the system contract. Since it's not present in ReactVMs, your calls will revert. Refer to the reactive demos for examples.

Reactive contracts running in the ReactVM context have limited capabilities for interaction with anything outside their VM. They can only do so by:

* Passively receiving log records passed to them by the reactive network.
* Initiating calls to destination chain contracts.

## Subscription Basics

Reactive contract's static subscriptions are configured by calling the `subscribe()` method of the Reactive Network's system contract upon deployment. This must happen in the `constructor()`, and the reactive contract must gracefully handle the reverts. The latter requirement is due to the fact the reactive contracts are deployed both to the Reactive Network as such, and to their deployer's private ReactVM, where the system contract is not present. The following code will accomplish this:

```
    bool private vm;

    constructor() {
        SubscriptionService service = SubscriptionService(service_address);
        bytes memory payload = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            CHAIN_ID,
            CONTRACT_ADDRESS,
            TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        (bool subscription_result,) = address(service).call(payload);
        if (!subscription_result) {
            vm = true;
        }
    }
```

Reactive contracts can change their subscription dynamically by using callbacks to Reactive Network instances (as opposed to ReactVM) of themselves, which can, in turn, call the system contract to effect the appropriate changes to subscriptions.

The subscription system allows the Reactive Network (the event provider) to associate any number of `uint256` fields with a given event. Subscribers can then request events that match any subset of these fields exactly. During the testnet stage, the Reactive Network provides the originating contract's chain ID, address, and all four topics as filtering criteria. These criteria may be expanded or changed in the future.

`REACTIVE_IGNORE` is a random value (`0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad`) set aside to indicate that you're not interested in the given topic. `0` is used for the same purpose where chain ID and contract address are concerned.

To explain the capabilities by example, **YOU CAN**:

* Subscribe to all log records emitted by a specific contract, e.g., to subscribe to all events from `0x7E0987E5b3a30e3f2828572Bb659A548460a3003`, call `subscribe(CHAIN_ID, 0x7E0987E5b3a30e3f2828572Bb659A548460a3003, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE)` in the constructor.

* Subscribe to all log records with a specific topic 0, e.g., to subscribe to all Uniswap V2 `Sync` events, call `subscribe(CHAIN_ID, 0, 0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1, REACTIVE_INGORE, REACTIVE_INGORE, REACTIVE_INGORE)` in the constructor.

* Subscribe to log records emitted by a specific contract with a specific topic 0.

* Specify multiple independent subscriptions -- just call `subscribe()` multiple times in constructor. Your reactive contract will receive events matching any of its subscriptions.

On the other hand, **YOU CAN'T**:

* Match the event parameters using less than, greater than, range, or bitwise operations. Only strict equality is supported.

* Use disjunction or sets of criteria in a single subscription. As pointed above, you can, however, call `subscribe()`multiple times, to achieve pretty much the same results, but this approach is somewhat vulnerable to combinatorial explosion.

## Processing Events

To process incoming events, reactive smart contract must implement the `IReactive` interface. This boils down to implementing a single method with the following signature:

```
    function react(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes calldata data,
        uint256 block_number,
        uint256 op_code
    ) external;
```

Reactive Network will feed the events matching the reactive contract's subscriptions by initiating calls to this method.

Reactive smart contracts may use all the EVM capabilities normally. The only limitation is that reactive contracts are executed in the context of a private ReactVM associated with a specific deployer address, so they cannot interact with contracts deployed by anyone else.

## Calls to Destination Chain Contracts

The key capability of reactive smart contracts is the ability to create new transactions in L1 networks. This is achieved by emitting log records of a predetermined format:

```
    event Callback(
        uint256 indexed chain_id,
        address indexed _contract,
        uint64 indexed gas_limit,
        bytes payload
    );
```

Upon observing such a record in the traces, the Reactive Network will submit a new transaction with the desired payload to the L1 network indicated by chain ID (as long as it's on the supported list). Note that for authorization purposes, the first 160 bits of the call arguments will be replaced with the calling reactive contract's RVM ID, which is equal to the reactive contract's deployer address.

For example, the Uniswap Stop Order Demo uses this capability to initiate token sales through its destination chain contract:

```
    bytes memory payload = abi.encodeWithSignature(
        "stop(address,address,address,bool,uint256,uint256)",
        0,
        pair,
        client,
        token0,
        coefficient,
        threshold
    );
    emit Callback(chain_id, stop_order, CALLBACK_GAS_LIMIT, payload);
```
