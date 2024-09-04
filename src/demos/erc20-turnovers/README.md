# ERC-20 Turnovers Demo

## Overview

This demo tracks ERC-20 token turnovers across all contracts, providing turnover data on request. It builds on the basic reactive setup and showcases two key functionalities:

- **Turnover Monitoring:** Observes token transfers to accumulate and report turnover data.
- **Reactive Data Calls:** Provides real-time turnover information via callbacks to the origin contract.

## Contracts

The demo involves two main contracts:

1. **Origin Chain Contract:** `TokenTurnoverL1` manages turnover requests and responses for ERC-20 tokens. It allows the owner to request turnover data, which is then processed and returned by a reactive contract via callbacks.

2. **Reactive Contract:** `TokenTurnoverReactive` listens for ERC-20 transfer events and specific requests from `TokenTurnoverL1`. It updates turnover records and responds to requests by emitting callbacks with current turnover data.

## Further Considerations

There are several opportunities for improvement:

- **Multi-Origin Subscriptions:** Expand to monitor multiple contracts for event tracking.
- **Dynamic Subscriptions:** Enable real-time adjustments to subscriptions, allowing flexible and responsive tracking.
- **Persistent State Management:** Maintain historical data context to improve reliability.
- **Dynamic Callbacks:** Use arbitrary transaction payloads for more complex interactions and automation.

## Deployment & Testing

To deploy and test the contracts, follow these steps. Ensure the following environment variables are configured appropriately:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`

You can use the recommended Sepolia RPC URL: `https://rpc2.sepolia.org`.

### Step 1

Deploy the origin chain contract and assign the contract address from the response to `TURNOVER_L1_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/erc20-turnovers/TokenTurnoverL1.sol:TokenTurnoverL1 --constructor-args 0x0000000000000000000000000000000000000000
```

### Step 2

Deploy the reactive contract and assign the contract address from the response to `TURNOVER_REACTIVE_ADDR`:

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc20-turnovers/TokenTurnoverReactive.sol:TokenTurnoverReactive --constructor-args $TURNOVER_L1_ADDR
```

### Step 3

Select a token contract address with some activity to monitor and assign it to `ACTIVE_TOKEN_ADDR`. Send a data request to the Sepolia contract.

```bash
cast send $TURNOVER_L1_ADDR "request(address)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $ACTIVE_TOKEN_ADDR
```

The contract should emit a log record with the collected turnover data of the specified token shortly thereafter.

### Step 4

To stop the reactive contract:

```bash
cast send $TURNOVER_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```bash
cast send $TURNOVER_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```