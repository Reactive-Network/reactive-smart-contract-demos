# ERC-20 Turnovers Demo

## Overview

The **ERC-20 Turnovers Demo** tracks ERC-20 token turnovers across all contracts, providing the relevant data on request. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic) and highlights two primary functionalities:

- **Turnover Monitoring**: Observes token transfers to accumulate and report turnover data.
- **Reactive Data Calls**: Provides real-time turnover information via callbacks to the origin contract.

## Contracts

**Origin/Destination Chain Contract**: [TokenTurnoverL1](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/erc20-turnovers/TokenTurnoverL1.sol) manages turnover requests and responses for ERC-20 tokens, allowing the owner to request turnover data, which is then processed and returned by the reactive contract via callbacks.

**Reactive Contract**: [TokenTurnoverReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/erc20-turnovers/TokenTurnoverReactive.sol) subscribes to ERC‑20 transfer events via `ERC20_TRANSFER_TOPIC_0` and request events from `TokenTurnoverL1` via `L1_RQ_TOPIC_0` on Ethereum Sepolia. When a transfer event is received, it updates the token’s turnover record and emits a `Turnover` event. If the contract detects a request from `TokenTurnoverL1`, it responds by emitting a `Callback` event containing the current turnover data for the requested token. This contract extends `AbstractPausableReactive`, allowing subscriptions to be paused or resumed as needed.

## Further Considerations

There are several opportunities for improvement:

- **Multi-Origin Subscriptions**: Expand to monitor multiple contracts for event tracking.
- **Dynamic Subscriptions**: Enable real-time adjustments to subscriptions, allowing flexible and responsive tracking.
- **Persistent State Management**: Maintain historical data context to improve reliability.
- **Dynamic Callbacks**: Use arbitrary transaction payloads for more complex interactions and automation.

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

Deploy the `TokenTurnoverL1` contract and assign the `Deployed to` address from the response to `TURNOVER_L1_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/erc20-turnovers/TokenTurnoverL1.sol:TokenTurnoverL1 --value 0.02ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR
```

### Step 2 — Reactive Contract

Deploy the `TokenTurnoverReactive` contract and assign the `Deployed to` address from the response to `TURNOVER_REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc20-turnovers/TokenTurnoverReactive.sol:TokenTurnoverReactive --value 0.1ether --constructor-args $TURNOVER_L1_ADDR
```

### Step 3 — Monitor Token Turnover

Use the USDT contract at `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` (or any active token) and send a request to `TURNOVER_L1_ADDR` to monitor its turnover. The contract will emit a log with the turnover data for the specified token shortly after the request.

```bash
cast send $TURNOVER_L1_ADDR "request(address)" --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0
```

### Step 4 — Reactive Contract State

To stop the reactive contract:

```bash
cast send $TURNOVER_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```bash
cast send $TURNOVER_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```