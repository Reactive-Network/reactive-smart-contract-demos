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

Deploy the contracts to Ethereum Sepolia and Reactive Kopli by following these steps. Ensure the following environment variables are configured:

* `SEPOLIA_RPC` — RPC URL for Ethereum Sepolia, (see [Chainlist](https://chainlist.org/chain/11155111))
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — RPC URL for Reactive Kopli (https://kopli-rpc.rkt.ink).
* `REACTIVE_PRIVATE_KEY` — Reactive Kopli private key
* `CLIENT_WALLET` — Deployer's EOA wallet address

[//]: # (* `SEPOLIA_CALLBACK_PROXY_ADDR` — 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8)

**Faucet**: To receive REACT tokens, send SepETH to the Reactive faucet at `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. An equivalent amount of REACT will be sent to your address.

### Step 1 — Test Tokens and Liquidity Pool

To test live, you'll need testnet tokens and a Uniswap V2 liquidity pool. Use pre-existing tokens or deploy your own.

```bash
export TK1=0x2AFDE4A3Bca17E830c476c568014E595EA916a04
export TK2=0x7EB2Ad352369bb6EDEb84D110657f2e40c912c95
```

To deploy ERC-20 tokens (if needed), provide a token name and symbol as constructor arguments. Each token mints 100 units to the deployer:

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args TK1 TK1
```

Repeat the command for the second token, using a different name and symbol:

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args TK2 TK2
```

### Step 2 — Uniswap V2 Pair

If you use pre-existing tokens shown in Step 1, export the address of their Uniswap pair:

```bash
export UNISWAP_V2_PAIR_ADDR=0x1DD11fD3690979f2602E42e7bBF68A19040E2e25
```

To create a new pair, use the Uniswap V2 Factory contract `0x7E0987E5b3a30e3f2828572Bb659A548460a3003` and the token addresses deployed in Step 1. After the transaction, retrieve the pair's address from the `PairCreated` event on [Sepolia scan](https://sepolia.etherscan.io/tx/0x4a373bc6ebe815105abf44e6b26e9cdcd561fb9e796196849ae874c7083692a4/advanced#eventlog):

```bash
cast send 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 'createPair(address,address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $TOKEN0_ADDR $TOKEN1_ADDR
```

**Note**: The token with the smaller hexadecimal address becomes `token0`; the other is `token1`. Compare token contract addresses alphabetically or numerically in hexadecimal format to determine their order.

### Step 3 — Destination Contract

Deploy the callback contract on Ethereum Sepolia, using the Uniswap V2 router at `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`, linked to the factory contract specified in Step 2. For the Uniswap Stop Order demo, you can skip the `AUTHORIZED_CALLER_ADDRESS` check by using `0x0000000000000000000000000000000000000000`.

Assign the `Deployed to` address from the response to `CALLBACK_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderCallback.sol:UniswapDemoStopOrderCallback --constructor-args 0x0000000000000000000000000000000000000000 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008
```

[//]: # (#### Callback Payment)

[//]: # ()
[//]: # (To ensure a successful callback, the callback contract must have an ETH balance. Find more details [here]&#40;https://dev.reactive.network/system-contract#callback-payments&#41;. To fund the contract, run the following command:)

[//]: # ()
[//]: # (```bash)

[//]: # (cast send $CALLBACK_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether)

[//]: # (```)

[//]: # ()
[//]: # (To cover the debt of the callback contact, run this command:)

[//]: # ()
[//]: # (```bash)

[//]: # (cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CALLBACK_ADDR "coverDebt&#40;&#41;")

[//]: # (```)

[//]: # ()
[//]: # (Alternatively, you can deposit funds into the [Callback Proxy]&#40;https://dev.reactive.network/origins-and-destinations&#41; contract on Sepolia, using the command below. The EOA address whose private key signs the transaction pays the fee.)

[//]: # ()
[//]: # (```bash)

[//]: # (cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $SEPOLIA_CALLBACK_PROXY_ADDR "depositTo&#40;address&#41;" $CALLBACK_ADDR --value 0.1ether)

[//]: # (```)

### Step 4 — Add Liquidity to the Pool

Transfer liquidity into the created pool:

```bash
cast send $TOKEN0_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

```bash
cast send $TOKEN1_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

Mint the liquidity pool tokens to your wallet:

```bash
cast send $UNISWAP_V2_PAIR_ADDR 'mint(address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CLIENT_WALLET
```

### Step 5 — Reactive Contract

Deploy the contract on the Reactive Network, specifying:

`UNISWAP_V2_PAIR_ADDR`: The pair address from Step 2.

`CALLBACK_ADDR`: The address from Step 3.

`CLIENT_WALLET`: The client initiating the order.

`DIRECTION_BOOLEAN`: `true` to sell `token0` and buy `token1`; `false` for the reverse.

`EXCHANGE_RATE_DENOMINATOR` and `EXCHANGE_RATE_NUMERATOR`: The exchange rate threshold, represented as integers. For example, a threshold of 1.234 requires DENOMINATOR=1000 and NUMERATOR=1234.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderReactive.sol:UniswapDemoStopOrderReactive --constructor-args $UNISWAP_V2_PAIR_ADDR $CALLBACK_ADDR $CLIENT_WALLET $DIRECTION_BOOLEAN $EXCHANGE_RATE_DENOMINATOR $EXCHANGE_RATE_NUMERATOR
```

### Step 6 — Authorize Token Spending

Authorize the destination chain contract to spend your tokens. The last parameter specifies the amount to approve. For tokens with 18 decimals, the example below authorizes the callback contract to spend one token:

```bash
cast send $TOKEN_ADDR 'approve(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000
```

### Step 7 — Adjust the Exchange Rate

To activate the reactive contract, directly adjust the exchange rate through the pair, bypassing the periphery contracts. Liquidity pools are simple and offer minimal functionality, making them cost-effective. Peripheral contracts, while more feature-rich and efficient for swaps, aren't suitable for this case as they limit our ability to directly modify the exchange rate.

Perform the adjustment by executing an inefficient swap directly through the pair:

```bash
cast send $TOKEN0_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 20000000000000000
```

Next, execute the swap at an unfavorable rate to create a significant shift in the exchange rate:

```bash
cast send $UNISWAP_V2_PAIR_ADDR 'swap(uint,uint,address,bytes calldata)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY 0 5000000000000000 $CLIENT_WALLET "0x"
```

The stop order will then be triggered and visible on [Sepolia scan](https://sepolia.etherscan.io/). The callback can be viewed on the destination contract's event log, as shown [here](https://sepolia.etherscan.io/address/0xA8AE573e5227555255AAb217a86f3E9fE1Fc6631#events).