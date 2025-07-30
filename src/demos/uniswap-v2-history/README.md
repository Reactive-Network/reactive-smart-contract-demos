# Uniswap V2 Exchange Rate History Demo

## Overview

The **Uniswap V2 Exchange Rate History Demo** tracks historical exchange rates from Uniswap V2 liquidity pools across chains. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic) and highlights two primary functionalities:

- **Historical Data Tracking:** Monitors and records exchange rate changes for Uniswap V2 pairs.
- **Resynchronization Requests:** Allows retrieval of past exchange rates via callbacks to the origin contract.

## Contracts

**Origin/Destination Chain Contract**: [UniswapHistoryDemoL1](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-history/UniswapHistoryDemoL1.sol) handles resynchronization requests and processes responses. It emits `RequestReSync` for new requests and `ReSync` for processed data.

**Reactive Contract**: [UniswapHistoryDemoReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-history/UniswapHistoryDemoReactive.sol) subscribes to Uniswap V2 `Sync` events via `UNISWAP_V2_SYNC_TOPIC_0` and resynchronization requests via `REQUEST_RESYNC_TOPIC_0` on Ethereum Sepolia. It maintains a history of pair reserves in a local data structure. When a new `Sync` event arrives, the contract appends a record of the updated reserves and emits its own `Sync` event. On detecting a resync request, it retrieves the last known reserves up to the requested block number and emits a `Callback` event containing those reserves. As an extension of `AbstractPausableReactive`, this contract also supports pausing and resuming subscriptions.

## Further Considerations

There are several opportunities for improvement:

- **Enhanced Subscription Management:** Supporting multiple origin contracts for broader coverage.
- **Real-time Configuration:** Dynamic subscription adjustments for flexible monitoring.
- **Persistent State Management:** Keeping historical data for improved reliability.
- **Dynamic Payloads:** Using flexible transaction payloads for more complex interactions.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `DESTINATION_RPC` — RPC URL for the destination chain, (see [Chainlist](https://chainlist.org)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `DESTINATION_CALLBACK_PROXY_ADDR` — The service address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).

> ℹ️ **Reactive Faucet on Sepolia**
> 
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/5, meaning you get 5 REACT for every 1 SepETH sent.
>
> **Important**: Do not send more than 10 SepETH per request, as doing so will cause you to lose the excess amount without receiving any additional REACT. The maximum that should be sent in a single transaction is 10 SepETH, which will yield 50 REACT.

> ⚠️ **Broadcast Error**
> 
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

### Step 1 — Origin/Destination Contract

Deploy the `UniswapHistoryDemoL1` contract and assign the `Deployed to` address from the response to `UNISWAP_L1_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoL1.sol:UniswapHistoryDemoL1 --value 0.02ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR
```

### Step 2 — Reactive Contract

Deploy the `UniswapHistoryDemoReactive` contract and assign the `Deployed to` address from the response to `UNISWAP_REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoReactive.sol:UniswapHistoryDemoReactive --value 0.1ether --constructor-args $UNISWAP_L1_ADDR
```

### Step 3 — Monitor Token Pair Activity

Assign the active pair address to `ACTIVE_PAIR_ADDR` and the block number to `BLOCK_NUMBER`. For example, use `0x85b6E66594C2DfAf7DC83b1a25D8FAE1091AF063` as the pair address and `6843582` as the block number. Send the data request to `UniswapHistoryDemoL1`. The contract will emit a log with the activity data shortly after.

```bash
cast send $UNISWAP_L1_ADDR "request(address,uint256)" --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0x85b6E66594C2DfAf7DC83b1a25D8FAE1091AF063 6843582
```

### Step 4 — Reactive Contract State

To stop the reactive contract:

```bash
cast send $UNISWAP_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```bash
cast send $UNISWAP_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
