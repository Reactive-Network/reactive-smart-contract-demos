# Uniswap V2 Stop Order Demo

## Overview

The **Uniswap V2 Stop Order Demo** implements a reactive smart contract that monitors `Sync` events in a Uniswap V2 liquidity pool. When the exchange rate reaches a predefined threshold, the contract automatically executes asset sales. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts that respond to real-time events.

## Contracts

**Token Contract**: [UniswapDemoToken](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol) is a basic ERC-20 token with 100 tokens minted to the deployer's address. It provides integration points for Uniswap swaps.

**Reactive Contract**: [UniswapDemoStopOrderReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderReactive.sol) subscribes to a Uniswap V2 pair’s `Sync` events via `UNISWAP_V2_SYNC_TOPIC_0` and a stop-order contract’s events via `STOP_ORDER_STOP_TOPIC_0` on Ethereum Sepolia. It continuously monitors the pair’s reserves. If the reserves drop below a specified threshold, it triggers a stop order by emitting a `Callback` event containing the necessary parameters. The stop order’s corresponding event confirms execution, after which the contract marks the process as complete. This contract demonstrates a simple reactive approach to automated stop-order logic on Uniswap V2 pairs.

**Origin/Destination Chain Contract**: [UniswapDemoStopOrderCallback](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderCallback.sol) processes stop orders. When the Reactive Network triggers the callback, the contract verifies the caller, checks the exchange rate and token balance, and performs the token swap through the Uniswap V2 router, transferring the swapped tokens back to the client. After execution, the contract emits a `Stop` event, signaling the reactive contract to conclude. The stateless callback contract can be used across multiple reactive stop orders with the same router.

## Further Considerations

The demo showcases essential stop order functionality but can be improved with:

- **Dynamic Event Subscriptions:** Supporting multiple orders and flexible event handling.
- **Sanity Checks and Retry Policies:** Adding error handling and retry mechanisms.
- **Support for Arbitrary Routers and DEXes:** Extending functionality to work with various routers and decentralized exchanges.
- **Improved Data Flow:** Refining interactions between reactive and destination chain contracts for better reliability.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `DESTINATION_RPC` — RPC URL for the destination chain, (see [Chainlist](https://chainlist.org)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `DESTINATION_CALLBACK_PROXY_ADDR` — The service address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
* `CLIENT_WALLET` — Deployer's EOA wallet address

> ℹ️ **Reactive Faucet on Sepolia**
> 
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/5, meaning you get 5 REACT for every 1 SepETH sent.
>
> **Important**: Do not send more than 10 SepETH per request, as doing so will cause you to lose the excess amount without receiving any additional REACT. The maximum that should be sent in a single transaction is 10 SepETH, which will yield 50 REACT.

> ⚠️ **Broadcast Error**
> 
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

### Step 1 — Test Tokens and Liquidity Pool

To test live, you'll need testnet tokens and a Uniswap V2 liquidity pool. Use pre-existing tokens or deploy your own.

```bash
export TK1=0x2AFDE4A3Bca17E830c476c568014E595EA916a04
export TK2=0x7EB2Ad352369bb6EDEb84D110657f2e40c912c95
```

To deploy ERC-20 tokens (if needed), provide a token name and symbol as constructor arguments. Each token mints 100 units to the deployer:

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args TK1 TK1
```

Repeat the command for the second token, using a different name and symbol:

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args TK2 TK2
```

### Step 2 — Uniswap V2 Pair

If you use pre-existing tokens shown in Step 1, export the address of their Uniswap pair:

```bash
export UNISWAP_V2_PAIR_ADDR=0x1DD11fD3690979f2602E42e7bBF68A19040E2e25
```

To create a new pair, use the Uniswap V2 Factory contract `0x7E0987E5b3a30e3f2828572Bb659A548460a3003` and the token addresses deployed in Step 1. After the transaction, retrieve the pair's address from the `PairCreated` event on [Sepolia scan](https://sepolia.etherscan.io/tx/0x4a373bc6ebe815105abf44e6b26e9cdcd561fb9e796196849ae874c7083692a4/advanced#eventlog).

```bash
cast send 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 'createPair(address,address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $TOKEN0_ADDR $TOKEN1_ADDR
```

> 📝 **Note**  
> The token with the smaller hexadecimal address becomes `token0`; the other is `token1`. Compare token contract addresses alphabetically or numerically in hexadecimal format to determine their order.

### Step 3 — Destination Contract

Deploy the callback contract on Ethereum Sepolia, using the Uniswap V2 router at `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`, linked to the factory contract specified in Step 2. You should also pass the Sepolia callback proxy address. Assign the `Deployed to` address from the response to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderCallback.sol:UniswapDemoStopOrderCallback --value 0.02ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008
```

### Step 4 — Add Liquidity to the Pool

Transfer liquidity into the created pool:

```bash
cast send $TOKEN0_ADDR 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

```bash
cast send $TOKEN1_ADDR 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

Mint the liquidity pool tokens to your wallet:

```bash
cast send $UNISWAP_V2_PAIR_ADDR 'mint(address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CLIENT_WALLET
```

### Step 5 — Reactive Contract

Deploy the Reactive contract specifying:

- `UNISWAP_V2_PAIR_ADDR`: The pair address from Step 2.
- `CALLBACK_ADDR`: The address from Step 3.
- `CLIENT_WALLET`: The wallet address initiating the order.
- `DIRECTION_BOOLEAN`: `true` to sell `token0` and buy `token1`; `false` for the reverse.
- `EXCHANGE_RATE_DENOMINATOR` and `EXCHANGE_RATE_NUMERATOR`: The exchange rate threshold, represented as integers. For example, a threshold of 1.234 would require `EXCHANGE_RATE_DENOMINATOR` to be set to `1000` and `EXCHANGE_RATE_NUMERATOR` to `1234`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderReactive.sol:UniswapDemoStopOrderReactive --value 0.1ether --constructor-args $UNISWAP_V2_PAIR_ADDR $CALLBACK_ADDR $CLIENT_WALLET $DIRECTION_BOOLEAN $EXCHANGE_RATE_DENOMINATOR $EXCHANGE_RATE_NUMERATOR
```

### Step 6 — Authorize Token Spending

Authorize the destination chain contract to spend your tokens. The last parameter specifies the amount to approve. For tokens with 18 decimals, the example below authorizes the callback contract to spend one token:

```bash
cast send $TOKEN_ADDR 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000
```

### Step 7 — Adjust the Exchange Rate

To activate the reactive contract, directly adjust the exchange rate through the pair, bypassing the periphery contracts. Liquidity pools are simple and offer minimal functionality, making them cost-effective. Peripheral contracts, while more feature-rich and efficient for swaps, aren't suitable for this case as they limit our ability to directly modify the exchange rate.

Perform the adjustment by executing an inefficient swap directly through the pair:

```bash
cast send $TOKEN_ADDR 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 20000000000000000
```

Next, execute the swap at an unfavorable rate to create a significant shift in the exchange rate:

```bash
cast send $UNISWAP_V2_PAIR_ADDR 'swap(uint,uint,address,bytes calldata)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0 5000000000000000 $CLIENT_WALLET "0x"
```

The stop order will then be triggered and visible on [Sepolia scan](https://sepolia.etherscan.io/). The callback can be viewed on the destination contract's event log, as shown [here](https://sepolia.etherscan.io/address/0xA8AE573e5227555255AAb217a86f3E9fE1Fc6631#events).