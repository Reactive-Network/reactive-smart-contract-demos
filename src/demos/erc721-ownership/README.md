# ERC-721 Ownership Demo

This demo monitors token ownership changes on all ERC-721 contracts and provides this information upon request.

## Deployment & Testing

To deploy and test the contracts, follow these steps. Ensure the following environment variables are configured appropriately:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SYSTEM_CONTRACT_ADDR`

### Step 1

Deploy the Origin Chain Contract and assign the contract address from the response to `OWNERSHIP_L1_ADDR`.

```
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipL1.sol:NftOwnershipL1 --constructor-args 0x0000000000000000000000000000000000000000
```

### Step 2

Deploy the Reactive Contract and assign the contract address from the response to `OWNERSHIP_REACTIVE_ADDR`.

```
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipReactive.sol:NftOwnershipReactive --constructor-args $SYSTEM_CONTRACT_ADDR $OWNERSHIP_L1_ADDR
```

### Step 3

Select a token contract address with some activity to monitor and assign it to `ACTIVE_TOKEN_ADDR`. Also, assign a specific token ID to `ACTIVE_TOKEN_ID`. Then, send a data request to the Sepolia contract.

```
cast send $OWNERSHIP_L1_ADDR "request(address,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $ACTIVE_TOKEN_ADDR $ACTIVE_TOKEN_ID
```

Shortly thereafter, the contract should emit a log record with the collected turnover data of the specified token.

### Step 4

To stop the reactive contract:

```
cast send $OWNERSHIP_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```
cast send $OWNERSHIP_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
