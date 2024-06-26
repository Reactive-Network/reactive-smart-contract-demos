# ERC-20 Turnovers Demo

This demo monitors token turnovers on all ERC-20 contracts and provides this information upon request.

## Deployment & Testing

You will need the following environment variables configured appropriately to follow this script:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SYSTEM_CONTRACT_ADDR`

Deploy the callback contract to Sepolia first:

```
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/erc20-turnovers/TokenTurnoverL1.sol:TokenTurnoverL1 --constructor-args 0x0000000000000000000000000000000000000000
```

Assign the contract address to `TURNOVER_L1_ADDR`.

Deploy the reactive contract:

```
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc20-turnovers/TokenTurnoverReactive.sol:TokenTurnoverReactive --constructor-args $SYSTEM_CONTRACT_ADDR $TURNOVER_L1_ADDR
```

Assign the contract address to `TURNOVER_REACTIVE_ADDR`.

Monitor the contract's activity, select an address of a token contract with some activity, and assign it to `ACTIVE_TOKEN_ADDR`.

Send a data request to the Sepolia contract:

```
cast send $TURNOVER_L1_ADDR "request(address)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $ACTIVE_TOKEN_ADDR
```

The contract should emit a log record with the collected turnover data of the specified token shortly thereafter.

Stop the reactive contract:

```
cast send $TURNOVER_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
