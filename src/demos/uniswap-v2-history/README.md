# Uniswap V2 Exchange Rate History Demo

This simple demo monitors sync events on all Uniswap V2 liquidity pools, and provides historical exchange rate information on request.

## Deployment for testing

You will need the following environment variables configured appropriately to follow this script:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SYSTEM_CONTRACT_ADDR`

Deploy the callback contract to Sepolia first:

```
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoL1.sol:UniswapHistoryDemoL1 --constructor-args 0x0000000000000000000000000000000000000000
```

Assign the contract address to `UNISWAP_L1_ADDR`.

Deploy the reactive contract:

```
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoReactive.sol:UniswapHistoryDemoReactive --constructor-args $SYSTEM_CONTRACT_ADDR $UNISWAP_L1_ADDR
```

Assign the contract address to `UNISWAP_REACTIVE_ADDR`.

Monitor the contract's activity, select an address of a pair with some activity, and assign it to `ACTIVE_PAIR_ADDR`. Assign a block number to `BLOCK_NUMBER`.

Send a data request to Sepolia contract:

```
cast send $UNISWAP_L1_ADDR "request(address,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $ACTIVE_PAIR_ADDR $BLOCK_NUMBER
```

The contract should emit a log record with collected turnover data on the token in question shortly thereafter.

Stop the reactive contract:

```
cast send $UNISWAP_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
