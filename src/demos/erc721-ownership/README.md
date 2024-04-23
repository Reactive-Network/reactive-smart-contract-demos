# ERC721 Ownership Demo

This simple demo monitors token ownership changes on all ERC721 contracts, and provides this information on request.

## Deployment for testing

You will need the following enviornment variables configured appropriately to follow this script:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SYSTEM_CONTRACT_ADDR`

Deploy the callback contract to Sepolia first:

```
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipL1.sol:NftOwnershipL1 --constructor-args 0x0000000000000000000000000000000000000000
```

Assign the contract address to `OWNERSHIP_L1_ADDR`.

Deploy the reactive contract:

```
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipReactive.sol:NftOwnershipReactive --constructor-args $SYSTEM_CONTRACT_ADDR $OWNERSHIP_L1_ADDR
```

Assign the contract address to `OWNERSHIP_REACTIVE_ADDR`.

Monitor the contract's activity, select an address of a token contract with some activity, and assign it to `ACTIVE_TOKEN_ADDR`. Assign a specific token ID to `ACTIVE_TOKEN_ID`.

Send a data request to Sepolia contract:

```
cast send $OWNERSHIP_L1_ADDR "request(address,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $ACTIVE_TOKEN_ADDR $ACTIVE_TOKEN_ID
```

The contract should emit a log record with collected turnover data on the token in question shortly thereafter.

Stop the reactive contract:

```
cast send $OWNERSHIP_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
