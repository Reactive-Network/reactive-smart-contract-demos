# ERC-721 Ownership Demo

## Overview

The **ERC-721 Ownership Demo** tracks ERC-721 token ownership and synchronizes ownership data across chains. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic) and highlights two primary functionalities:

- **Ownership Tracking:** Monitors ERC-721 ownership changes and updates records.
- **Reactive Data Calls:** Provides real-time ownership information via callbacks to the origin contract.

## Contracts

**Origin/Destination Chain Contract**: [NftOwnershipL1](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/erc721-ownership/NftOwnershipL1.sol) manages ownership requests and responses for ERC-721 tokens, allowing the owner to request ownership data, which is then processed and returned by the reactive contract via callbacks.

**Reactive Contract**: [NftOwnershipReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/erc721-ownership/NftOwnershipReactive.sol) subscribes to ERC‑721 transfer events via `ERC721_TRANSFER_TOPIC_0` and ownership‑related requests via `L1_RQ_TOPIC_0` from the `NftOwnershipL1` contract on Ethereum Sepolia. When an eligible transfer is recorded, it appends the new owner to the token’s ownership list and emits an `OwnershipTransfer` event. On detecting a request from `NftOwnershipL1`, it responds by emitting a `Callback` event containing the full ownership history for the requested token. As an extension of `AbstractPausableReactive`, this contract also supports pausing and resuming its subscriptions.

## Further Considerations

There are several opportunities for improvement:

- **Multi-Origin Subscriptions:** Tracking multiple contracts for detailed event coverage.
- **Dynamic Subscriptions:** Real-time adjustment of subscriptions for flexible monitoring.
- **Persistent State Management:** Maintaining historical ownership data for improved reliability.
- **Flexible Callbacks:** Using dynamic transaction payloads for complex interactions.

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

Deploy the `NftOwnershipL1` contract and assign the `Deployed to` address from the response to `OWNERSHIP_L1_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipL1.sol:NftOwnershipL1 --value 0.02ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR
```

### Step 2 — Reactive Contract

Deploy the `NftOwnershipReactive` contract and assign the `Deployed to` address from the response to `OWNERSHIP_REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipReactive.sol:NftOwnershipReactive --value 0.1ether --constructor-args $OWNERSHIP_L1_ADDR
```

### Step 3 — Monitor Token Ownership

Assign the active token address to `ACTIVE_TOKEN_ADDR` and the token ID to `ACTIVE_TOKEN_ID`. For example, use `0x92eFBC2F5208b8610E57c52b9E49F7189048900F` as the address and `129492` as the token ID. Then, send a data request to `OWNERSHIP_L1_ADDR`. The contract will emit a log with the ownership data for the specified token shortly after the request.

```bash
cast send $OWNERSHIP_L1_ADDR "request(address,uint256)" --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0x92eFBC2F5208b8610E57c52b9E49F7189048900F 129492
```

### Step 4 — Reactive Contract State

To stop the reactive contract:

```bash
cast send $OWNERSHIP_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```bash
cast send $OWNERSHIP_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
