# Reactive Network Demo

## Overview

The **Reactive Network Demo** illustrates a basic use case of the Reactive Network with two key functionalities:

* Low-latency monitoring of logs emitted by contracts on the origin chain (Sepolia testnet).
* Executing calls from the Reactive Network to contracts on the destination chain, also on Sepolia.

This setup can be adapted for various scenarios, from simple stop orders to fully decentralized algorithmic trading.

## Contracts

**Origin Chain Contract**: [BasicDemoL1Contract](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoL1Contract.sol) receives Ether and returns it to the sender, emitting a `Received` event with transaction details.

**Reactive Contract**: [BasicDemoReactiveContract](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoReactiveContract.sol) demonstrates a reactive subscription model on Ethereum Sepolia. It listens for logs from a specified contract and emits an `Event` for each incoming log while incrementing a local `counter`. If the incoming log’s `topic_3` value is at least `0.01 Ether`, it emits a `Callback` event containing a payload to invoke a `callback` function externally.

**Destination Chain Contract**: [BasicDemoL1Callback](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoL1Callback.sol) logs callback details upon receiving a call, capturing the origin, sender, and reactive sender addresses. It could also be a third-party contract.

## Further Considerations

The demo highlights just a subset of Reactive Network's features. Potential improvements include:

- **Enhanced Event Subscriptions**: Subscribing to multiple event origins, including callback logs, to maintain consistency.
- **Dynamic Subscriptions**: Allowing real-time adjustments to subscriptions based on conditions.
- **State Management**: Introducing persistent state handling for more complex, context-aware reactions.
- **Flexible Callbacks**: Supporting arbitrary transaction payloads to increase adaptability.

## Deployment & Testing

Deploy the contracts to Ethereum Sepolia and Reactive Kopli by following these steps. Ensure the following environment variables are configured:

* `SEPOLIA_RPC` — RPC URL for Ethereum Sepolia, (see [Chainlist](https://chainlist.org/chain/11155111))
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — RPC URL for Reactive Kopli (see [Reactive Docs](https://dev.reactive.network/kopli-testnet#reactive-kopli-information))
* `REACTIVE_PRIVATE_KEY` — Reactive Kopli private key

**Faucet**: To receive REACT tokens, send SepETH to the Reactive faucet at `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. An equivalent amount of REACT will be sent to your address.

### Step 1 — Origin Contract

Deploy the `BasicDemoL1Contract` contract and assign the `Deployed to` address from the response to `ORIGIN_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/basic/BasicDemoL1Contract.sol:BasicDemoL1Contract
```

### Step 2 — Destination Contract

Deploy the `BasicDemoL1Callback` contract and assign the `Deployed to` address from the response to `CALLBACK_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/basic/BasicDemoL1Callback.sol:BasicDemoL1Callback
```

### Step 3 — Reactive Contract

Deploy the `BasicDemoReactiveContract` contract, configuring it to listen to `ORIGIN_ADDR` and to send callbacks to `CALLBACK_ADDR`. The `Received` event on the origin contract has a topic 0 value of `0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb`, which we are monitoring.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/basic/BasicDemoReactiveContract.sol:BasicDemoReactiveContract --value 0.1ether --constructor-args $KOPLI_CALLBACK_PROXY_ADDR $ORIGIN_ADDR 0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb $CALLBACK_ADDR
```

### Step 4 — Test Reactive Callback

Test the whole setup by sending some ether to `ORIGIN_ADDR`:

```bash
cast send $ORIGIN_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether
```

Ensure that the value sent is at least 0.1 ether, as this is the minimum required to trigger the process. Meeting this threshold will prompt the Reactive Network to initiate a callback transaction to `CALLBACK_ADDR` like shown [here](https://sepolia.etherscan.io/address/0x26fF307f0f0Ea0C4B5Df410Efe22754324DACE08#events).
