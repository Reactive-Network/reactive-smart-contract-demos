# Reactive Network Basic Demo

## Overview

The **Reactive Network Basic Demo** walks through the core Reactive pattern: a contract on an origin chain emits an event, Reactive detects it and automatically sends a callback to a contract on a destination chain. The destination contract doesn't contain any real business logic. It simply receives the callback, confirming that Reactive Network has performed its function successfully.

The demo focuses on two key behaviors. First, **low-latency monitoring**: Reactive watches for log events emitted by a contract on the origin chain. Second, **conditional reacting**: when a threshold is met (in this case, a transfer of at least **0.001 ETH**), Reactive triggers a callback to the destination chain.

![Demo Flow](./img/flow.png)

The setup is intentionally minimal. The same pattern applies to more complex scenarios like stop orders, cross-chain arbitrage, or decentralized algorithmic trading.

## Contracts

**Origin Contract**: [BasicDemoL1Contract](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoL1Contract.sol) is the origin contract that accepts Ether, returns it to the sender, and emits a `Received` event containing the transaction origin, sender, and value. This event is what Reactive Network monitors.

**Reactive Contract**: [BasicDemoReactiveContract](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoReactiveContract.sol) is the Reactive contract, deployed on Reactive Network itself. On deployment, it subscribes to `Received` events from the origin contract. When an event arrives, the `react()` function checks whether the value (`topic_3`) meets a minimum threshold of **0.001 ETH**. If it does, the contract emits a `Callback` event with a payload targeting the destination contract.

**Destination Contract**: [BasicDemoL1Callback](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoL1Callback.sol) is the destination contract. It receives callbacks from Reactive Network, verifying that the caller is the authorized callback proxy, and emits a `CallbackReceived` event logging the transaction origin, sender, and Reactive sender addresses.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `ORIGIN_RPC` — RPC URL for the origin chain, (see [Chainlist](https://chainlist.org)).
* `ORIGIN_CHAIN_ID` — ID of the origin blockchain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#mainnet-chains)).
* `ORIGIN_PRIVATE_KEY` — Private key for signing transactions on the origin chain.
* `DESTINATION_RPC` — RPC URL for the destination chain, (see [Chainlist](https://chainlist.org)).
* `DESTINATION_CHAIN_ID` — ID of the destination blockchain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#mainnet-chains)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `DESTINATION_CALLBACK_PROXY_ADDR` — The service address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).

> ℹ️ **Reactive Faucet on Ethereum Sepolia**
>
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/100, meaning you get 100 REACT for every 1 SepETH sent.
>
> **Important**: Do not send more than 5 SepETH per request, as doing so will cause you to lose the excess amount without receiving any additional REACT. The maximum that should be sent in a single transaction is 5 SepETH, which will yield 500 REACT.

> ⚠️ **Broadcast Error**
> 
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

### Step 1 — Origin Contract

Deploy the `BasicDemoL1Contract` contract and assign the `Deployed to` address from the response to `ORIGIN_ADDR`.

```bash
forge create --broadcast --rpc-url $ORIGIN_RPC --private-key $ORIGIN_PRIVATE_KEY src/demos/basic/BasicDemoL1Contract.sol:BasicDemoL1Contract
```

### Step 2 — Destination Contract

Deploy the `BasicDemoL1Callback` contract and assign the `Deployed to` address from the response to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/basic/BasicDemoL1Callback.sol:BasicDemoL1Callback --value 0.02ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR
```

### Step 3 — Reactive Contract

Deploy the `BasicDemoReactiveContract` contract, configuring it to listen to `ORIGIN_ADDR` on `ORIGIN_CHAIN_ID` and to send callbacks to `CALLBACK_ADDR` on `DESTINATION_CHAIN_ID`. The `Received` event on the origin contract has a `topic_0` value of `0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb`, which we are monitoring.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/basic/BasicDemoReactiveContract.sol:BasicDemoReactiveContract --value 0.1ether --constructor-args $ORIGIN_CHAIN_ID $DESTINATION_CHAIN_ID $ORIGIN_ADDR 0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb $CALLBACK_ADDR
```

### Step 4 — Test Reactive Callback

Test the whole setup by sending some ether to `ORIGIN_ADDR`:

```bash
cast send $ORIGIN_ADDR --rpc-url $ORIGIN_RPC --private-key $ORIGIN_PRIVATE_KEY --value 0.001ether
```

Ensure that the value sent is at least 0.001 ether, as this is the minimum required to trigger the process. Meeting this threshold will prompt the Reactive Network to initiate a callback transaction to `CALLBACK_ADDR` like shown [here](https://sepolia.etherscan.io/address/0x26fF307f0f0Ea0C4B5Df410Efe22754324DACE08#events).
