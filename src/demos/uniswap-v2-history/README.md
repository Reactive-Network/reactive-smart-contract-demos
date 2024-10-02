# Uniswap V2 Exchange Rate History Demo

## Overview

This demo tracks historical exchange rates from Uniswap V2 liquidity pools across chains. It builds on the basic reactive demo with two primary functionalities:

- **Historical Data Tracking:** Monitors and records exchange rate changes for Uniswap V2 pairs.
- **Resynchronization Requests:** Allows retrieval of past exchange rates via callbacks to the origin contract.

## Contracts

The demo features two key contracts:

1. **Origin Chain Contract:** `UniswapHistoryDemoL1` handles resynchronization requests and processes responses. It emits `RequestReSync` for new requests and `ReSync` for processed data.

2. **Reactive Contract:** `UniswapHistoryDemoReactive` subscribes to Uniswap V2 sync events and processes resynchronization requests. It updates historical reserve data and emits `Sync` events for new data.

## Further Considerations

The demo shows basic historical rate tracking but can be improved with:

- **Enhanced Subscription Management:** Supporting multiple origin contracts for broader coverage.
- **Real-time Configuration:** Dynamic subscription adjustments for flexible monitoring.
- **Persistent State Management:** Keeping historical data for improved reliability.
- **Dynamic Payloads:** Using flexible transaction payloads for more complex interactions.

## Deployment & Testing

To deploy and test the contracts, follow these steps. Ensure the following environment variables are configured appropriately:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SEPOLIA_CALLBACK_PROXY_ADDR`

You can use the recommended Sepolia RPC URL: `https://rpc2.sepolia.org`.

### Step 1

Deploy the origin chain contract and assign the contract address from the response to `UNISWAP_L1_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoL1.sol:UniswapHistoryDemoL1 --constructor-args 0x0000000000000000000000000000000000000000
```

#### Callback Payment

To ensure a successful callback, the callback contract must have an ETH balance. Find more details [here](https://dev.reactive.network/system-contract#callback-payments). To fund the contract, run the following command:

```bash
cast send $CALLBACK_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether
```

To cover the debt of the callback contact, run this command:

```bash
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CALLBACK_ADDR "coverDebt()"
```

Alternatively, you can deposit funds into the [Callback Proxy](https://dev.reactive.network/origins-and-destinations) contract on Sepolia, using the command below. The EOA address whose private key signs the transaction pays the fee.

```bash
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $SEPOLIA_CALLBACK_PROXY_ADDR "depositTo(address)" $CALLBACK_ADDR --value 0.1ether
```

### Step 2

Deploy the reactive contract and assign the contract address from the response to `UNISWAP_REACTIVE_ADDR`.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoReactive.sol:UniswapHistoryDemoReactive --constructor-args $UNISWAP_L1_ADDR
```

### Step 3

Monitor the contract's activity by selecting an active pair address and assigning it to `ACTIVE_PAIR_ADDR`. Then, specify the desired block number and assign it to `BLOCK_NUMBER`.

Send a data request to the Sepolia contract:

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
