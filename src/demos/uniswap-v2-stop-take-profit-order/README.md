# Uniswap V2 Stop-Loss & Take-Profit Orders

## Overview

The **Uniswap V2 Stop-Loss & Take-Profit Orders** system implements a personal Reactive contract that automatically executes trades on Uniswap V2 when predefined price thresholds are reached. Each user deploys their own instance for complete control and privacy over their stop-loss and take-profit orders.

The system manages subscriptions dynamically: it subscribes to a pair's `Sync` events when the first order is created and unsubscribes when all orders for that pair are completed or cancelled. Orders include built-in retry logic with cooldowns, and the callback contract extends `RescuableBase` for recovering ETH or tokens that may become stuck during execution.

## Contracts

**Reactive Contract**: [UniswapDemoStopTakeProfitReactive](./UniswapDemoStopTakeProfitReactive.sol) runs on Reactive Network. On deployment, it subscribes to five lifecycle events from the callback contract: `StopOrderCreated`, `StopOrderCancelled`, `StopOrderExecuted`, `StopOrderPaused`, and `StopOrderResumed`. When a new order is created, the contract tracks it internally and dynamically subscribes to that pair's `Sync` events. On each `Sync`, the `react()` function computes the current price from the reserves and checks it against each active order's threshold (below for stop-loss, above for take-profit). If the condition is met, it emits a `Callback` targeting `executeStopOrder` on the destination chain. Once execution is confirmed via `StopOrderExecuted`, it untracks the order and unsubscribes from the pair if no active orders remain. The contract includes trigger cooldowns and a maximum attempt limit to prevent repeated failed executions.

**Destination Contract**: [UniswapDemoStopTakeProfitCallback](./UniswapDemoStopTakeProfitCallback.sol) lives on the destination chain and is deployed per user for isolated order management. Users create orders by specifying a pair, direction, amount, and price threshold. When triggered by the Reactive Network, the contract re-verifies the price on-chain, transfers the user's approved tokens, executes the swap through the Uniswap V2 Router, and returns the proceeds. Orders can be paused, resumed, or cancelled at any time. The contract includes retry logic with cooldowns and extends `RescuableBase` for recovering ETH or tokens that may become stuck during execution.

**Rescuable Base Contract**: [RescuableBase](./RescuableBase.sol) is an abstract contract that provides emergency fund recovery. The owner can rescue specific amounts or full balances of ETH and ERC-20 tokens through safe transfer mechanisms.

## Deployment & Testing

### Environment Variables

Before deploying, set the following environment variables:

* `DESTINATION_RPC` — RPC URL for the destination chain, (see [Chainlist](https://chainlist.org)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on Reactive Network.
* `DESTINATION_CALLBACK_PROXY_ADDR` — The callback proxy address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
* `USER_WALLET` — Deployer's EOA wallet address

> ℹ️ **Reactive faucet on Ethereum Sepolia**
>
> To receive testnet REACT, send SepETH to the Reactive faucet on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The exchange rate is 100 REACT per 1 SepETH. Do not send more than 5 SepETH in a single transaction as any excess is lost.

> ⚠️ **Broadcast Error**
>
> If you see `error: unexpected argument '--broadcast' found`, your Foundry version does not support the `--broadcast` flag for `forge create`. Remove it from the command and re-run.

### Step 1 — Test Tokens

You can use pre-existing tokens or deploy your own. To use pre-existing tokens, export their addresses and skip the deployment commands:

```bash
export TOKEN0=0x2AFDE4A3Bca17E830c476c568014E595EA916a04
export TOKEN1=0x7EB2Ad352369bb6EDEb84D110657f2e40c912c95
```

To deploy new ERC-20 tokens, run the following for each. Each mints 100 tokens to the deployer:

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args TK1 TK1
```

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args TK2 TK2
```

### Step 2 — Uniswap V2 Pair

If you're using the pre-existing tokens from Step 1, export their pair address:

```bash
export UNISWAP_V2_PAIR_ADDR=0x1DD11fD3690979f2602E42e7bBF68A19040E2e25
```

To create a new pair, call `createPair()` on the Uniswap V2 Factory at `0x7E0987E5b3a30e3f2828572Bb659A548460a3003`. After the transaction, retrieve the pair address from the `PairCreated` event on [Sepolia Etherscan](https://sepolia.etherscan.io/tx/0x4a373bc6ebe815105abf44e6b26e9cdcd561fb9e796196849ae874c7083692a4/advanced#eventlog) and export it as `UNISWAP_V2_PAIR_ADDR`.

```bash
cast send 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 'createPair(address,address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $TOKEN0 $TOKEN1
```

> 📝 **Note**  
>
> Token ordering is determined by address: the token with the smaller hexadecimal address becomes `token0`, the other becomes `token1`.

### Step 3 — Add Liquidity to the Pool

Transfer 10 tokens of each type into the pair and mint the LP tokens to your wallet:

```bash
cast send $TOKEN0 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

```bash
cast send $TOKEN1 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

```bash
cast send $UNISWAP_V2_PAIR_ADDR 'mint(address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $USER_WALLET
```

### Step 4 — Callback Contract

Deploy `UniswapDemoStopOrderCallback` with the relevant [callback proxy address](https://dev.reactive.network/origins-and-destinations#callback-proxy-address) and the Uniswap V2 Router at `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`. Save the `Deployed to` address as `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-take-profit-order/UniswapDemoStopTakeProfitCallback.sol:UniswapDemoStopTakeProfitCallback --value 0.02ether --constructor-args $USER_WALLET $DESTINATION_CALLBACK_PROXY_ADDR 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008
```

### Step 5 — Reactive Contract

Deploy `UniswapDemoStopTakeProfitReactive` with your wallet address and the destination contract address from Step 4. Save the `Deployed to` address as `REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-stop-take-profit-order/UniswapDemoStopTakeProfitReactive.sol:UniswapDemoStopTakeProfitReactive --value 0.1ether --constructor-args $USER_WALLET $CALLBACK_ADDR
```

### Step 6 — Approve Token Spending

The destination contract needs permission to spend the client's tokens. Approve it by specifying the token address and amount. The example below approves 1 token (with 18 decimals):

```bash
cast send $TOKEN0 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000
```

### Step 7 — Create a Stop-Loss Order

Create an order that sells `token0` for `token1` when the price drops below a threshold. The arguments are:

- `UNISWAP_V2_PAIR_ADDR`: The pair address from Step 2.
- `SELL_TOKEN0`: `true` to sell `token0`, `false` to sell `token1`.
- `AMOUNT`: Amount of tokens to sell (in wei).
- `COEFFICIENT`: Price calculation coefficient (typically `10000` for 4 decimal precision).
- `THRESHOLD`: Price threshold that triggers the order.
- `ORDER_TYPE`: `0` for stop-loss, `1` for take-profit.

This example creates a stop-loss order to sell 1 `token0` when the price drops to 0.8 (`8000/10000`):

```bash
cast send $CALLBACK_ADDR 'createStopOrder(address,bool,uint256,uint256,uint256,uint8)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR true 1000000000000000000 10000 8000 0
```

### Step 8 — Create a Take-Profit Order

This example creates a take-profit order to sell 1 `token0` when the price rises to 1.2 (`12000/10000`):

```bash
cast send $CALLBACK_ADDR 'createStopOrder(address,bool,uint256,uint256,uint256,uint8)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR true 1000000000000000000 10000 12000 1
```

### Step 9 — Trigger Order Execution

To test the Reactive contract, shift the exchange rate by performing a direct swap through the pair. First, transfer tokens into the pair:

```bash
cast send $TOKEN0 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 20000000000000000
```

Then execute a swap to change the price:

```bash
cast send $UNISWAP_V2_PAIR_ADDR 'swap(uint,uint,address,bytes calldata)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0 5000000000000000 $USER_WALLET "0x"
```

The Reactive contract will detect the price change and trigger any orders whose thresholds have been crossed. You can verify execution on [Sepolia Etherscan](https://sepolia.etherscan.io/).

### Step 10 — Managing Orders

Orders can be paused, resumed, or cancelled at any time through the destination contract. The parameter is the order ID (starting from `0`).

Pause an order:

```bash
cast send $CALLBACK_ADDR 'pauseStopOrder(uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0
```

Resume a paused order:

```bash
cast send $CALLBACK_ADDR 'resumeStopOrder(uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0
```

Cancel an order:

```bash
cast send $CALLBACK_ADDR 'cancelStopOrder(uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0
```

View all orders or only active ones:

```bash
cast call $CALLBACK_ADDR 'getAllOrders()' --rpc-url $DESTINATION_RPC
```

View active orders:
```bash
cast call $CALLBACK_ADDR 'getActiveOrders()' --rpc-url $DESTINATION_RPC
```