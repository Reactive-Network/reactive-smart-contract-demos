# Uniswap V2 Exchange Rate History Demo

## Overview

The **Uniswap V2 Exchange Rate History Demo** tracks historical exchange rates from Uniswap V2 liquidity pools across chains. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic) and highlights two primary functionalities:

- **Historical Data Tracking:** Monitors and records exchange rate changes for Uniswap V2 pairs.
- **Resynchronization Requests:** Allows retrieval of past exchange rates via callbacks to the origin contract.

## Contracts

- **Origin/Destination Chain Contract:** [UniswapHistoryDemoL1](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-history/UniswapHistoryDemoL1.sol) handles resynchronization requests and processes responses. It emits `RequestReSync` for new requests and `ReSync` for processed data.

- **Reactive Contract:** [UniswapHistoryDemoReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-history/UniswapHistoryDemoReactive.sol) subscribes to Uniswap V2 sync events and processes resynchronization requests. It updates historical reserve data and emits `Sync` events for new data.

## Further Considerations

There are several opportunities for improvement:

- **Enhanced Subscription Management:** Supporting multiple origin contracts for broader coverage.
- **Real-time Configuration:** Dynamic subscription adjustments for flexible monitoring.
- **Persistent State Management:** Keeping historical data for improved reliability.
- **Dynamic Payloads:** Using flexible transaction payloads for more complex interactions.

## Deployment & Testing

To deploy the contracts to Ethereum Sepolia and Kopli Testnet, follow these steps. Replace the relevant keys, addresses, and endpoints as needed. Make sure the following environment variables are correctly configured before proceeding:

* `SEPOLIA_RPC` — https://ethereum-sepolia-rpc.publicnode.com/ or https://1rpc.io/sepolia
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — https://kopli-rpc.rkt.ink
* `REACTIVE_PRIVATE_KEY` — Kopli Testnet private key
* `SEPOLIA_CALLBACK_PROXY_ADDR` — 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8

**Note**: To receive REACT, send SepETH to the Reactive faucet on Ethereum Sepolia (`0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`). An equivalent amount will be sent to your address.

### Step 1

Deploy the origin chain contract and assign the contract address from the response to `UNISWAP_L1_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoL1.sol:UniswapHistoryDemoL1 --constructor-args 0x0000000000000000000000000000000000000000
```

[//]: # (#### Callback Payment)

[//]: # ()
[//]: # (To ensure a successful callback, the callback contract must have an ETH balance. Find more details [here]&#40;https://dev.reactive.network/system-contract#callback-payments&#41;. To fund the contract, run the following command:)

[//]: # ()
[//]: # (```bash)

[//]: # (cast send $UNISWAP_L1_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether)

[//]: # (```)

[//]: # ()
[//]: # (To cover the debt of the callback contact, run this command:)

[//]: # ()
[//]: # (```bash)

[//]: # (cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $UNISWAP_L1_ADDR "coverDebt&#40;&#41;")

[//]: # (```)

[//]: # ()
[//]: # (Alternatively, you can deposit funds into the [Callback Proxy]&#40;https://dev.reactive.network/origins-and-destinations&#41; contract on Sepolia, using the command below. The EOA address whose private key signs the transaction pays the fee.)

[//]: # ()
[//]: # (```bash)

[//]: # (cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $SEPOLIA_CALLBACK_PROXY_ADDR "depositTo&#40;address&#41;" $UNISWAP_L1_ADDR --value 0.1ether)

[//]: # (```)

### Step 2

Deploy the reactive contract and assign the contract address from the response to `UNISWAP_REACTIVE_ADDR`.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoReactive.sol:UniswapHistoryDemoReactive --constructor-args $UNISWAP_L1_ADDR
```

### Step 3

Monitor the contract's activity by selecting an active pair address and assigning it to `ACTIVE_PAIR_ADDR`. Then, specify the desired block number and assign it to `BLOCK_NUMBER`. Send a data request to the Sepolia contract. You can use `0x85b6E66594C2DfAf7DC83b1a25D8FAE1091AF063` as pair address and `6843582` as block number.

```bash
cast send $UNISWAP_L1_ADDR "request(address,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $ACTIVE_PAIR_ADDR $BLOCK_NUMBER
```

The contract should emit a log record with the collected turnover data of the specified token shortly thereafter.

### Step 4

To stop the reactive contract:

```bash
cast send $UNISWAP_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```bash
cast send $UNISWAP_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
