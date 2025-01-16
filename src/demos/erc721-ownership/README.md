# ERC-721 Ownership Demo

## Overview

The **ERC-721 Ownership Demo** tracks ERC-721 token ownership and synchronizes ownership data across chains. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic) and highlights two primary functionalities:

- **Ownership Tracking:** Monitors ERC-721 ownership changes and updates records.
- **Reactive Data Calls:** Provides real-time ownership information via callbacks to the origin contract.

## Contracts

**Origin/Destination Chain Contract:** [NftOwnershipL1](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/erc721-ownership/NftOwnershipL1.sol) manages ownership requests and responses for ERC-721 tokens, allowing the owner to request ownership data, which is then processed and returned by the reactive contract via callbacks.

**Reactive Contract**:  
[NftOwnershipReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/erc721-ownership/NftOwnershipReactive.sol) subscribes to ERC‑721 transfer events via `ERC721_TRANSFER_TOPIC_0` and ownership‑related requests via `L1_RQ_TOPIC_0` from the `NftOwnershipL1` contract on Ethereum Sepolia. When an eligible transfer is recorded, it appends the new owner to the token’s ownership list and emits an `OwnershipTransfer` event. On detecting a request from `NftOwnershipL1`, it responds by emitting a `Callback` event containing the full ownership history for the requested token. As an extension of `AbstractPausableReactive`, this contract also supports pausing and resuming its subscriptions.

## Further Considerations

There are several opportunities for improvement:

- **Multi-Origin Subscriptions:** Tracking multiple contracts for detailed event coverage.
- **Dynamic Subscriptions:** Real-time adjustment of subscriptions for flexible monitoring.
- **Persistent State Management:** Maintaining historical ownership data for improved reliability.
- **Flexible Callbacks:** Using dynamic transaction payloads for complex interactions.

## Deployment & Testing

Deploy the contracts to Ethereum Sepolia and Reactive Kopli by following these steps. Ensure the following environment variables are configured:

* `SEPOLIA_RPC` — RPC URL for Ethereum Sepolia, (see [Chainlist](https://chainlist.org/chain/11155111))
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — RPC URL for Reactive Kopli (https://kopli-rpc.rkt.ink).
* `REACTIVE_PRIVATE_KEY` — Reactive Kopli private key
* `SEPOLIA_CALLBACK_PROXY_ADDR` — 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8

**Faucet**: To receive REACT tokens, send SepETH to the Reactive faucet at `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. An equivalent amount of REACT will be sent to your address.

### Step 1 — Origin/Destination Contract

Deploy the `NftOwnershipL1` contract and assign the `Deployed to` address from the response to `OWNERSHIP_L1_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipL1.sol:NftOwnershipL1 --constructor-args $SEPOLIA_CALLBACK_PROXY_ADDR
```

[//]: # (#### Callback Payment)

[//]: # ()
[//]: # (To ensure a successful callback, the callback contract must have an ETH balance. Find more details [here]&#40;https://dev.reactive.network/system-contract#callback-payments&#41;. To fund the contract, run the following command:)

[//]: # ()
[//]: # (```bash)

[//]: # (cast send $OWNERSHIP_L1_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether)

[//]: # (```)

### Step 2 — Reactive Contract

Deploy the `NftOwnershipReactive` contract and assign the `Deployed to` address from the response to `OWNERSHIP_REACTIVE_ADDR`.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipReactive.sol:NftOwnershipReactive --value 0.1ether --constructor-args $OWNERSHIP_L1_ADDR
```

### Step 3 — Monitor Token Ownership

Assign the active token address to `ACTIVE_TOKEN_ADDR` and the token ID to `ACTIVE_TOKEN_ID`. For example, use `0x92eFBC2F5208b8610E57c52b9E49F7189048900F` as the address and `129492` as the token ID. Then, send a data request to `OWNERSHIP_L1_ADDR`. The contract will emit a log with the ownership data for the specified token shortly after the request.

```bash
cast send $OWNERSHIP_L1_ADDR "request(address,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY 0x92eFBC2F5208b8610E57c52b9E49F7189048900F 129492
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
