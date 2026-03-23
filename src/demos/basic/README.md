# Reactive Network Demo

## Overview

The **Reactive Network Demo** illustrates a basic use case of the Reactive Network with two key functionalities:

* Low-latency monitoring of logs emitted by a contract on the origin chain.
* Executing calls from the Reactive Network to a contract on the destination chain.

This setup can be adapted for various scenarios, from simple stop orders to fully decentralized algorithmic trading.

## Contracts

**Origin Contract**: [BasicDemoL1Contract](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoL1Contract.sol) receives Ether and returns it to the sender, emitting a `Received` event with transaction details.

**Reactive Contract**: [BasicDemoReactiveContract](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoReactiveContract.sol) demonstrates a reactive subscription model. It subscribes to logs from a specified contract and processes event data in a decentralized manner. The contract subscribes to events from a specified contract on the origin chain. Upon receiving a log, the contract checks if `topic_3` is at least 0.01 Ether. If the condition is met, it emits a `Callback` event containing a payload to invoke an external callback function on the destination chain.

**Destination Contract**: [BasicDemoL1Callback](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/basic/BasicDemoL1Callback.sol) serves as the destination contract for handling reactive callbacks. When triggered by a cross-chain event, it logs key transaction details while ensuring only authorized senders can invoke the callback. Upon execution, it emits a `CallbackReceived` event, capturing metadata such as the origin, sender, and reactive sender addresses.

## Further Considerations

The demo highlights just a fraction of Reactive Network’s capabilities. Future enhancements could include:

- **Expanded Event Subscriptions**: Monitoring multiple event sources, including callback logs.
- **Dynamic Subscriptions**: Adjusting subscriptions in real-time based on evolving conditions.
- **State Persistence**: Maintaining contract state for more complex, context-aware reactions.
- **Versatile Callbacks**: Enabling customizable transaction payloads to improve adaptability.

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

> ℹ️ **Reactive Faucet on Sepolia**
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

Blockchain Explorer: [BasicDemoL1Contract Deployment](https://sepolia.etherscan.io/tx/0x14ae6d36240645af1c5e642ebc8fa308a907d787442272d149124d64827bd686) | [Contract Address](https://sepolia.etherscan.io/address/0xDb6fF08Bf6C3691437436E26A51B9BDeBA9d1007)

### Step 2 — Destination Contract

Deploy the `BasicDemoL1Callback` contract and assign the `Deployed to` address from the response to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/basic/BasicDemoL1Callback.sol:BasicDemoL1Callback --value 0.02ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR
```

Blockchain Explorer: [BasicDemoL1Callback Deployment](https://lasna.reactscan.net/tx/0xabe317d70fd1d06019684650364a7639886da80a58b20d81949562d4f51dd4c5) | [Contract Address](https://lasna.reactscan.net/address/0x49abe186a9b24f73e34ccae3d179299440c352ac/contract/0x709e939B7335BB4Eb119d0732B72Df54B0ce50F6)

### Step 3 — Reactive Contract

Deploy the `BasicDemoReactiveContract` contract, configuring it to listen to `ORIGIN_ADDR` on `ORIGIN_CHAIN_ID` and to send callbacks to `CALLBACK_ADDR` on `DESTINATION_CHAIN_ID`. The `Received` event on the origin contract has a `topic_0` value of `0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb`, which we are monitoring.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/basic/BasicDemoReactiveContract.sol:BasicDemoReactiveContract --value 0.1ether --constructor-args $ORIGIN_CHAIN_ID $DESTINATION_CHAIN_ID $ORIGIN_ADDR 0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb $CALLBACK_ADDR
```

Blockchain Explorer: [BasicDemoReactiveContract Deployment](https://lasna.reactscan.net/tx/0x3c598cf553c0a7ddc81562f6064a10c0b99e721eda46bf2f9da9c3333ff9d6f5) | [Contract Address](https://lasna.reactscan.net/address/0x49abe186a9b24f73e34ccae3d179299440c352ac/contract/0xdd7B4C3154eD2116500E8Fc4d87B49BEF31157ff)

### Step 4 — Test Reactive Callback

Test the whole setup by sending some ether to `ORIGIN_ADDR`:

```bash
cast send $ORIGIN_ADDR --rpc-url $ORIGIN_RPC --private-key $ORIGIN_PRIVATE_KEY --value 0.001ether
```

Blockchain Explorer: [Test Callback Transaction](https://sepolia.etherscan.io/tx/0xbd495f332629ae1366d138ed29f8168dbda028560707b3cd0662d294c63b1bd9)

Ensure that the value sent is at least 0.001 ether, as this is the minimum required to trigger the process. Meeting this threshold will prompt the Reactive Network to initiate a callback transaction to `CALLBACK_ADDR` like shown [here](https://sepolia.etherscan.io/address/0x26fF307f0f0Ea0C4B5Df410Efe22754324DACE08#events).
