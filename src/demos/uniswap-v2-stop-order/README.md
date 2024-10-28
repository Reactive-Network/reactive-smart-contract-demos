# Uniswap V2 Stop Order Demo

## Overview

The **Uniswap V2 Stop Order Demo** implements a reactive smart contract that monitors `Sync` events in a Uniswap V2 liquidity pool. When the exchange rate reaches a predefined threshold, the contract automatically executes asset sales. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts that respond to real-time events.

## Contracts

- **Origin Chain Contract:** [UniswapDemoToken](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol) is a basic ERC-20 token with 100 tokens minted to the deployer's address. It provides integration points for Uniswap swaps.

- **Reactive Contract:** [UniswapDemoStopOrderReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderReactive.sol) subscribes to a Uniswap V2 pair and stop order events. It checks if reserves fall below a threshold and triggers a stop order via callback.

- **Destination Chain Contract:** [UniswapDemoStopOrderCallback](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderCallback.sol) processes stop orders. When the Reactive Network triggers the callback, the contract verifies the caller, checks the exchange rate and token balance, and performs the token swap through the Uniswap V2 router, transferring the swapped tokens back to the client. After execution, the contract emits a `Stop` event, signaling the reactive contract to conclude. The stateless callback contract can be used across multiple reactive stop orders with the same router.

## Further Considerations

The demo showcases essential stop order functionality but can be improved with:

- **Dynamic Event Subscriptions:** Supporting multiple orders and flexible event handling.
- **Sanity Checks and Retry Policies:** Adding error handling and retry mechanisms.
- **Support for Arbitrary Routers and DEXes:** Extending functionality to work with various routers and decentralized exchanges.
- **Improved Data Flow:** Refining interactions between reactive and destination chain contracts for better reliability.

## Deployment & Testing

To deploy the contracts to Ethereum Sepolia and Kopli Testnet, follow these steps. Replace the relevant keys, addresses, and endpoints as needed. Make sure the following environment variables are correctly configured before proceeding:

* `SEPOLIA_RPC` — https://rpc2.sepolia.org
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — https://kopli-rpc.rkt.ink
* `REACTIVE_PRIVATE_KEY` — Kopli Testnet private key
* `SEPOLIA_CALLBACK_PROXY_ADDR` — 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8

**Note**: To receive REACT, send SepETH to the Reactive faucet on Ethereum Sepolia (`0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`). An equivalent amount will be sent to your address.

### Step 1

To test this live, you will need some testnet tokens and a Uniswap V2 liquidity pool for them. Use any pre-existing tokens and pair or deploy your own.

```bash
export TK1=0x6436F8EAeC14d458163D9D166755c633625214d5
export TK2=0x0c179306f12679f9d8f9829abb99d1a7c9b5e6ce
```

Deploy two ERC-20 tokens if needed. The constructor arguments are the token name and token symbol, which you can choose as you like. Upon creation, the token mints and transfers 100 units to the deployer.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args $TOKEN_NAME $TOKEN_SYMBOL
```

Repeat the above command for the second token with a different name and symbol:

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args $TOKEN_NAME $TOKEN_SYMBOL
```

### Step 2

```bash
export UNISWAP_V2_PAIR_ADDR=0xdaF8A2B4f96dd8E2A1Fd9B09d42d6C569e7382b7
```

Create a Uniswap V2 pair (pool) using the token addresses created in Step 1 (or skip and export the pair given above). Use the `PAIR_FACTORY_CONTRACT` address `0x7E0987E5b3a30e3f2828572Bb659A548460a3003`. You should get the newly created pair address from the transaction logs on [Sepolia scan](https://sepolia.etherscan.io/) where the `PairCreated` event is emitted.

**Note:** When determining which token is `token0` and which is `token1` in a Uniswap pair, the token with the smaller hexadecimal address value is designated as `token0`, and the other token is `token1`. This means you compare the two token contract addresses in their hexadecimal form, and the one that comes first alphabetically (or numerically since hexadecimal includes both numbers and letters) is `token0`.

```bash
cast send $PAIR_FACTORY_CONTRACT 'createPair(address,address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $TOKEN0_ADDR $TOKEN1_ADDR
```

### Step 3

Deploy the destination chain contract to Sepolia. Use the Uniswap V2 router at `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`, which is associated with the factory contract at `0x7E0987E5b3a30e3f2828572Bb659A548460a3003`.

The `$AUTHORIZED_CALLER_ADDRESS` parameter can be omitted for the Uniswap stop order demo, as the contract executing the stop order already verifies its correctness. To skip this check, use the address `0x0000000000000000000000000000000000000000`.

Assign the `Deployed to` address from the response to `CALLBACK_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderCallback.sol:UniswapDemoStopOrderCallback --constructor-args $AUTHORIZED_CALLER_ADDR $UNISWAP_V2_ROUTER_ADDR
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

### Step 4

Transfer some liquidity into the created pool:

```bash
cast send $TOKEN0_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

```bash
cast send $TOKEN1_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $$UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

```bash
cast send $UNISWAP_V2_PAIR_ADDR 'mint(address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CLIENT_WALLET
```

### Step 5

Deploy the reactive stop order contract to the Reactive Network, specifying the following:

`UNISWAP_V2_PAIR_ADDR`: The Uniswap pair address from Step 2.

`CALLBACK_ADDR`: The contract address from Step 3.

`CLIENT_WALLET`: The client's address initiating the order.

`DIRECTION_BOOLEAN`: `true` to sell `token0` and buy `token1`; `false` for the opposite.

`EXCHANGE_RATE_DENOMINATOR` and `EXCHANGE_RATE_NUMERATOR`: Integer representation of the exchange rate threshold below which a stop order is executed. These variables are set this way because the EVM works only with integers. As an example, to set the threshold at 1.234, the numerator should be 1234 and the denominator should be 1000.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderReactive.sol:UniswapDemoStopOrderReactive --constructor-args $UNISWAP_V2_PAIR_ADDR $CALLBACK_ADDR $CLIENT_WALLET $DIRECTION_BOOLEAN $EXCHANGE_RATE_DENOMINATOR $EXCHANGE_RATE_NUMERATOR
```

### Step 6

To initiate a stop order, authorize the destination chain contract to spend your tokens. The last parameter is the raw amount you intend to authorize. For tokens with 18 decimal places, the following example allows the callback contract to spend one token.

```bash
cast send $TOKEN_ADDR 'approve(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000
```

### Step 7

After creating the pair and adding liquidity, we have to make the reactive smart contract work by adjusting the exchange rate directly through the pair, not the periphery.

Liquidity pools are rather simple and primitive contracts. They offer little functionality and don't protect the user from mistakes, making their deployment cheaper. That's why most users perform swaps through so-called peripheral contracts. These contracts are deployed once and can interact with any pair created by a single contract. They offer features to limit slippage, maximize swap efficiency, and more.

However, since our goal is to change the exchange rate, these sophisticated features are a hindrance. Instead of swapping through the periphery, we perform an inefficient swap directly through the pair, achieving the desired rate shift.

```bash
cast send $TOKEN0_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 20000000000000000
```

The following command executes a swap at a highly unfavorable rate, causing an immediate and significant shift in the exchange rate:

```bash
cast send $UNISWAP_V2_PAIR_ADDR 'swap(uint,uint,address,bytes calldata)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY 0 5000000000000000 $CLIENT_WALLET "0x"
```

After that, the stop order will be executed and visible on [Sepolia scan](https://sepolia.etherscan.io/).