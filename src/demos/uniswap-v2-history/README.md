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

Deploy the contracts to Ethereum Sepolia and Reactive Kopli by following these steps. Ensure the following environment variables are configured:

* `SEPOLIA_RPC` — RPC URL for Ethereum Sepolia, (see [Chainlist](https://chainlist.org/chain/11155111))
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — RPC URL for Reactive Kopli (see [Reactive Docs](https://dev.reactive.network/kopli-testnet#reactive-kopli-information))
* `REACTIVE_PRIVATE_KEY` — Reactive Kopli private key
* `SEPOLIA_CALLBACK_PROXY_ADDR` — 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8_

**Faucet**: To receive REACT tokens, send SepETH to the Reactive faucet at `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. An equivalent amount of REACT will be sent to your address.

### Step 1 — Origin/Destination Contract

Deploy the `UniswapHistoryDemoL1` contract and assign the `Deployed to` address from the response to `UNISWAP_L1_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoL1.sol:UniswapHistoryDemoL1 --constructor-args $SEPOLIA_CALLBACK_PROXY_ADDR
```

### Step 2 — Reactive Contract

Deploy the `UniswapHistoryDemoReactive` contract and assign the `Deployed to` address from the response to `UNISWAP_REACTIVE_ADDR`.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoReactive.sol:UniswapHistoryDemoReactive --value 0.1ether --constructor-args $UNISWAP_L1_ADDR
```

### Step 3 — Monitor Token Pair Activity

Assign the active pair address to `ACTIVE_PAIR_ADDR` and the block number to `BLOCK_NUMBER`. For example, use `0x85b6E66594C2DfAf7DC83b1a25D8FAE1091AF063` as the pair address and `6843582` as the block number. Send the data request to `UniswapHistoryDemoL1`. The contract will emit a log with the activity data shortly after.

```bash
cast send $UNISWAP_L1_ADDR "request(address,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY 0x85b6E66594C2DfAf7DC83b1a25D8FAE1091AF063 6843582
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
