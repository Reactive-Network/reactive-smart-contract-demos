# ERC-721 Ownership Demo

## Overview

This demo tracks ERC-721 token ownership and synchronizes ownership data across chains. It extends the basic reactive setup and highlights two main functionalities:

- **Ownership Tracking:** Monitors ERC-721 ownership changes and updates records.
- **Reactive Data Calls:** Provides real-time ownership information via callbacks to the origin contract.

## Contracts

The demo involves two key contracts:

1. **Origin Chain Contract:** `NftOwnershipL1` manages ownership requests and responses for ERC-721 tokens. It allows the owner to request ownership data, which is then processed and returned by a reactive contract.

2. **Reactive Contract:** `NftOwnershipReactive` listens for ERC-721 transfer events and requests from `NftOwnershipL1`. It updates ownership records and responds with callbacks containing current ownership data.

## Further Considerations

The demo covers essential ownership tracking but can be improved with:

- **Multi-Origin Subscriptions:** Tracking multiple contracts for detailed event coverage.
- **Dynamic Subscriptions:** Real-time adjustment of subscriptions for flexible monitoring.
- **Persistent State Management:** Maintaining historical ownership data for improved reliability.
- **Flexible Callbacks:** Using dynamic transaction payloads for complex interactions.

## Deployment & Testing

To deploy and test the contracts, follow these steps. Ensure the following environment variables are configured appropriately:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`

You can use the recommended Sepolia RPC URL: `https://rpc2.sepolia.org`.

### Step 1

Deploy the origin chain contract and assign the contract address from the response to `OWNERSHIP_L1_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipL1.sol:NftOwnershipL1 --constructor-args 0x0000000000000000000000000000000000000000
```

### Step 2

Deploy the reactive contract and assign the contract address from the response to `OWNERSHIP_REACTIVE_ADDR`.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipReactive.sol:NftOwnershipReactive --constructor-args $OWNERSHIP_L1_ADDR
```

### Step 3

Select a token contract address with some activity to monitor and assign it to `ACTIVE_TOKEN_ADDR`. Also, assign a specific token ID to `ACTIVE_TOKEN_ID`. Then, send a data request to the Sepolia contract.

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
