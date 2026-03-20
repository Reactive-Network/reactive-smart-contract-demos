# Reactive Network Demo

## Overview

The **Reactive Network Demo** illustrates a basic use case of the Reactive Network with two key functionalities:

* Low-latency monitoring of logs emitted by a contract on the origin chain.
* Executing calls from the Reactive Network to a contract on the destination chain.

This setup can be adapted for various scenarios, from simple stop orders to fully decentralized algorithmic trading.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `ORIGIN_RPC` — RPC URL for the origin chain (see [Chainlist](https://chainlist.org)).
* `ORIGIN_CHAIN_ID` — ID of the origin blockchain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#mainnet-chains)).
* `ORIGIN_PRIVATE_KEY` — Private key for signing transactions on the origin chain.
* `DESTINATION_RPC` — RPC URL for the destination chain (see [Chainlist](https://chainlist.org)).
* `DESTINATION_CHAIN_ID` — ID of the destination blockchain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#mainnet-chains)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `DESTINATION_CALLBACK_PROXY_ADDR` — The service address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).

> ℹ️ **Reactive Faucet on Sepolia**
>
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/100, meaning you get 100 REACT for every 1 SepETH sent.
>
> **Important**: Do not send more than 5 SepETH per request, as doing so will cause you to lose the excess amount without receiving any additional REACT. The maximum that should be sent in a single transaction is 5 SepETH, which will yield 500 REACT.

> ⚠️ **Broadcast Error**
>
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

---

## Contracts

**Origin Contract**: [BasicDemoL1Contract](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoL1Contract.sol) receives Ether and returns it to the sender, emitting a `Received` event with transaction details.

**Reactive Contract**: [BasicDemoReactiveContract](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoReactiveContract.sol) demonstrates a reactive subscription model. It subscribes to logs from a specified contract and processes event data in a decentralized manner. The contract subscribes to events from a specified contract on the origin chain. Upon receiving a log, the contract checks if `topic_3` is at least 0.01 Ether. If the condition is met, it emits a `Callback` event containing a payload to invoke an external callback function on the destination chain.

**Destination Contract**: [BasicDemoL1Callback](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoL1Callback.sol) serves as the destination contract for handling reactive callbacks. When triggered by a cross-chain event, it logs key transaction details while ensuring only authorized senders can invoke the callback. Upon execution, it emits a `CallbackReceived` event, capturing metadata such as the origin, sender, and reactive sender addresses.

---

## System Workflow

### How It Works — End-to-End Flow

```
User sends ≥ 0.01 ETH to Origin Contract (BasicDemoL1Contract) on origin chain
            ↓
Origin Contract receives ETH, returns it to sender, emits Received event
            (topic_3 encodes the amount sent)
            ↓
Reactive Contract (on Reactive Network) detects the Received event from the origin chain
            ↓
Reactive Contract checks: is topic_3 (amount) ≥ 0.01 ETH?
            ↓ (if YES)
Reactive Contract emits a Callback event with a payload targeting the Destination Contract
            ↓
Reactive Network's system contract calls the Destination Contract on the destination chain
            ↓
Destination Contract verifies the authorized sender, logs cross-chain metadata, emits CallbackReceived event
```

### Key Design Decisions

- **Amount-gated reactions**: The Reactive contract only fires if the value sent to the Origin contract meets a minimum threshold (0.001 ETH). This demonstrates how reactive contracts can encode conditional logic before triggering cross-chain actions.
- **Separate origin and destination chains**: The origin and destination chains can be different networks. The Reactive Network acts as a trust layer bridging events from one chain to calls on another.
- **Authorization on destination**: The Destination contract checks that the caller is the authorized Reactive proxy — preventing unauthorized actors from calling the callback directly.
- **Topic-based filtering**: The Reactive contract reads `topic_3` from the `Received` event to extract the ETH amount, showing how on-chain event data can be used in reactive logic without additional off-chain infrastructure.

---

## Step-by-Step Walkthrough

### Phase 1: Deploy Origin Contract

**Step 1 — Deploy BasicDemoL1Contract on the origin chain**

Assign `Deployed to` to `ORIGIN_ADDR`.

```bash
forge create --broadcast --rpc-url $ORIGIN_RPC --private-key $ORIGIN_PRIVATE_KEY src/demos/basic/BasicDemoL1Contract.sol:BasicDemoL1Contract
```

---

### Phase 2: Deploy Destination Contract

**Step 2 — Deploy BasicDemoL1Callback on the destination chain**

Pass `DESTINATION_CALLBACK_PROXY_ADDR` as the constructor argument. Assign `Deployed to` to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/basic/BasicDemoL1Callback.sol:BasicDemoL1Callback --value 0.02ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR
```

---

### Phase 3: Deploy Reactive Contract

**Step 3 — Deploy BasicDemoReactiveContract on the Reactive Network**

This wires together the origin chain event to the destination chain callback. The `topic_0` for the `Received` event is `0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/basic/BasicDemoReactiveContract.sol:BasicDemoReactiveContract --value 0.1ether --constructor-args $ORIGIN_CHAIN_ID $DESTINATION_CHAIN_ID $ORIGIN_ADDR 0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb $CALLBACK_ADDR
```

At this point the Reactive contract is live and subscribed to the `Received` event from your Origin contract. Any qualifying ETH send will now trigger a cross-chain callback.

---

### Phase 4: Trigger the Reactive Callback

**Step 4 — Send ETH to the Origin Contract**

Send at least 0.001 ETH. Smaller amounts will not trigger the Reactive contract.

```bash
cast send $ORIGIN_ADDR --rpc-url $ORIGIN_RPC --private-key $ORIGIN_PRIVATE_KEY --value 0.001ether
```

What happens next (automatically, within a few blocks):

1. Origin contract emits `Received` event with the amount in `topic_3`.
2. Reactive Network detects the event and evaluates the amount condition.
3. Reactive contract emits `Callback` event targeting your Destination contract.
4. Reactive Network proxy calls the Destination contract on the destination chain.
5. Destination contract emits `CallbackReceived` event with cross-chain metadata.


---

## Further Considerations

The demo highlights just a fraction of Reactive Network's capabilities. Future enhancements could include:

- **Expanded Event Subscriptions**: Monitoring multiple event sources, including callback logs.
- **Dynamic Subscriptions**: Adjusting subscriptions in real-time based on evolving conditions.
- **State Persistence**: Maintaining contract state for more complex, context-aware reactions.
- **Versatile Callbacks**: Enabling customizable transaction payloads to improve adaptability.