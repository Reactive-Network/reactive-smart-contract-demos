# ERC-721 Ownership Demo

## Overview

The **ERC-721 Ownership Demo** tracks ERC-721 token ownership and synchronizes ownership data across chains. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic) and highlights two primary functionalities:

- **Ownership Tracking:** Monitors ERC-721 ownership changes and updates records.
- **Reactive Data Calls:** Provides real-time ownership information via callbacks to the origin contract.

## Contracts

- **Origin/Destination Chain Contract:** [NftOwnershipL1](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/erc721-ownership/NftOwnershipL1.sol) manages ownership requests and responses for ERC-721 tokens, allowing the owner to request ownership data, which is then processed and returned by the reactive contract via callbacks.

- **Reactive Contract:** [NftOwnershipReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/erc721-ownership/NftOwnershipReactive.sol) listens for ERC-721 transfer events and requests from `NftOwnershipL1`. It updates ownership records and responds with callbacks containing current ownership data.

## Further Considerations

There are several opportunities for improvement:

- **Multi-Origin Subscriptions:** Tracking multiple contracts for detailed event coverage.
- **Dynamic Subscriptions:** Real-time adjustment of subscriptions for flexible monitoring.
- **Persistent State Management:** Maintaining historical ownership data for improved reliability.
- **Flexible Callbacks:** Using dynamic transaction payloads for complex interactions.

## Deployment & Testing

To deploy the contracts to Ethereum Sepolia and Kopli Testnet, follow these steps. Replace the relevant keys, addresses, and endpoints as needed. Make sure the following environment variables are correctly configured before proceeding:

* `SEPOLIA_RPC` — https://rpc2.sepolia.org
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — https://kopli-rpc.rkt.ink
* `REACTIVE_PRIVATE_KEY` — Kopli Testnet private key
* `SEPOLIA_CALLBACK_PROXY_ADDR` — 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8

**Note**: To receive REACT, send SepETH to the Reactive faucet on Ethereum Sepolia (`0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`). An equivalent amount will be sent to your address.

### Step 1

Deploy the origin chain contract and assign the contract address from the response to `OWNERSHIP_L1_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipL1.sol:NftOwnershipL1 --constructor-args 0x0000000000000000000000000000000000000000
```

#### Callback Payment

To ensure a successful callback, the callback contract must have an ETH balance. Find more details [here](https://dev.reactive.network/system-contract#callback-payments). To fund the contract, run the following command:

```bash
cast send $OWNERSHIP_L1_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether
```

To cover the debt of the callback contact, run this command:

```bash
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $OWNERSHIP_L1_ADDR "coverDebt()"
```

Alternatively, you can deposit funds into the [Callback Proxy](https://dev.reactive.network/origins-and-destinations) contract on Sepolia, using the command below. The EOA address whose private key signs the transaction pays the fee.

```bash
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $SEPOLIA_CALLBACK_PROXY_ADDR "depositTo(address)" $OWNERSHIP_L1_ADDR --value 0.1ether
```

### Step 2

Deploy the reactive contract and assign the contract address from the response to `OWNERSHIP_REACTIVE_ADDR`.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipReactive.sol:NftOwnershipReactive --constructor-args $OWNERSHIP_L1_ADDR
```

### Step 3

Select a token contract address with some activity to monitor and assign it to `ACTIVE_TOKEN_ADDR`. Also, assign a specific token ID to `ACTIVE_TOKEN_ID`. Send a data request to the Sepolia contract. You can use `0x92eFBC2F5208b8610E57c52b9E49F7189048900F` as your active token address with token ID `129492`.

```bash
cast send $OWNERSHIP_L1_ADDR "request(address,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $ACTIVE_TOKEN_ADDR $ACTIVE_TOKEN_ID
```

The contract should emit a log record with the collected turnover data of the specified token shortly thereafter.

### Step 4

To stop the reactive contract:

```bash
cast send $OWNERSHIP_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```bash
cast send $OWNERSHIP_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
