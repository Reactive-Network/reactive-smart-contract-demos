# Uniswap V2 Stop-Loss & Take-Profit Orders

## Overview

The **Uniswap V2 Stop-Loss & Take-Profit Orders** system implements a personal reactive smart contract that automatically executes trades on Uniswap V2 when predefined price thresholds are reached. Each user deploys their own instance for complete control and privacy over their stop-loss and take-profit orders. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts that respond to real-time events.

## Contracts

**Reactive Contract**: [UniswapDemoStopTakeProfitReactive](./UniswapDemoStopTakeProfitReactive.sol) monitors a Uniswap V2 pair's `Sync` events via `UNISWAP_V2_SYNC_TOPIC_0` on Ethereum Sepolia. It tracks user-created stop-loss and take-profit orders by subscribing to lifecycle events (`StopOrderCreated`, `StopOrderCancelled`, `StopOrderExecuted`, `StopOrderPaused`, `StopOrderResumed`) emitted by the callback contract. When reserve changes indicate that a price threshold has been crossed, the contract emits a `Callback` event to trigger order execution. The contract dynamically subscribes to pairs when the first order is created and unsubscribes when all orders for a pair are completed or cancelled, optimizing gas usage.

**Origin/Destination Chain Contract**: [UniswapDemoStopTakeProfitCallback](./UniswapDemoStopTakeProfitCallback.sol) manages the creation and execution of stop-loss and take-profit orders. Users create orders specifying the pair, direction, amount, and price threshold. When triggered by the Reactive Network, the callback contract performs a final on-chain price verification, transfers tokens from the user's wallet, executes the swap through the Uniswap V2 router, and returns the purchased tokens to the user. The contract includes retry logic, pausable orders, and emergency rescue functions for stuck funds. Each user deploys their own instance for isolated order management and complete control over their trading strategy.

**Rescuable Base Contract**: [RescuableBase](./RescuableBase.sol) provides emergency rescue functionality for ETH and ERC20 tokens that may become stuck in the callback contract. This abstract contract allows the owner to recover funds with specific amounts or full balances through safe transfer mechanisms.

## Further Considerations

The demo showcases essential stop-loss and take-profit functionality but can be improved with:

- **Advanced Order Types:** Supporting trailing stops, conditional orders, and time-based constraints.
- **Multi-Pair Order Management:** Aggregating orders across multiple pairs for unified portfolio management.
- **Slippage Protection:** Adding configurable slippage limits to prevent unfavorable execution prices.
- **Gas Optimization:** Batching order execution and reducing storage costs for large order volumes.
- **Support for Arbitrary DEXes:** Extending functionality to work with Uniswap V3, SushiSwap, and other decentralized exchanges.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `DESTINATION_RPC` — RPC URL for the destination chain (see [Chainlist](https://chainlist.org)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `DESTINATION_CALLBACK_PROXY_ADDR` — The service address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
* `USER_WALLET` — Your EOA wallet address that will own the orders.

> ℹ️ **Reactive Faucet on Sepolia**
>
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/100, meaning you get 100 REACT for every 1 SepETH sent.
>
> **Important**: Do not send more than 5 SepETH per request, as doing so will cause you to lose the excess amount without receiving any additional REACT. The maximum that should be sent in a single transaction is 5 SepETH, which will yield 500 REACT.

> ⚠️ **Broadcast Error**
>
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

### Step 1 — Test Tokens and Liquidity Pool

To test live, you'll need testnet tokens and a Uniswap V2 liquidity pool. Use pre-existing tokens or deploy your own.

```bash
export TOKEN0=0x2AFDE4A3Bca17E830c476c568014E595EA916a04
export TOKEN1=0x7EB2Ad352369bb6EDEb84D110657f2e40c912c95
```

To deploy ERC-20 tokens (if needed), provide a token name and symbol as constructor arguments. Each token mints 100 units to the deployer:

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args TK1 TK1
```

Blockchain Explorer: [TK1 Deployment](https://sepolia.etherscan.io/tx/0x2f6cd1c511918cea09c89fee5d48f4f1b7ee54c3802f952f94594f4511b3e9bd) | [Contract Address](https://sepolia.etherscan.io/address/0x938e09E683FB0ae4c591BB0b92efF8f5CFd37255)

Repeat the command for the second token, using a different name and symbol:

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args TK2 TK2
```

Blockchain Explorer: [TK2 Deployment](https://sepolia.etherscan.io/tx/0x2285c5cf1b82ac1d0eca0a6310035f120559869290df2f3b7bc4335ef61aff72) | [Contract Address](https://sepolia.etherscan.io/address/0xC81cc3bC3e10cfE2474Ad52e84C57C4CD96Ede3f)

### Step 2 — Uniswap V2 Pair

If you use pre-existing tokens shown in Step 1, export the address of their Uniswap pair:

```bash
export UNISWAP_V2_PAIR_ADDR=0x1DD11fD3690979f2602E42e7bBF68A19040E2e25
```

To create a new pair, use the Uniswap V2 Factory contract `0x7E0987E5b3a30e3f2828572Bb659A548460a3003` and the token addresses deployed in Step 1. After the transaction, retrieve the pair's address from the `PairCreated` event on [Sepolia scan](https://sepolia.etherscan.io/).

```bash
cast send 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 'createPair(address,address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $TOKEN0 $TOKEN1
```

Blockchain Explorer: [Create Pair Transaction](https://sepolia.etherscan.io/tx/0x71ab6b6978d89a8bc89e3bb8731be39b7f288b7497967009449d48d358041885)

> 📝 **Note**
>
> The token with the smaller hexadecimal address becomes `token0`; the other is `token1`. Compare token contract addresses alphabetically or numerically in hexadecimal format to determine their order.

### Step 3 — Add Liquidity to the Pool

Transfer liquidity into the created pool:

```bash
cast send $TOKEN0 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

```bash
cast send $TOKEN1 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

Mint the liquidity pool tokens to your wallet:

```bash
cast send $UNISWAP_V2_PAIR_ADDR 'mint(address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $USER_WALLET
```

Blockchain Explorer: [Transfer TK1 to Pair](https://sepolia.etherscan.io/tx/0x4c6b4cdd86112a1ef41178058a54fe529e230f5b32b4ec23b8aca98309c5f749) | [Transfer TK2 to Pair](https://sepolia.etherscan.io/tx/0x7fc607ae7c48047e92351227f2e4f437243658605d91c644afeb494e7dc6c1a6) | [Mint LP Tokens](https://sepolia.etherscan.io/tx/0xa8a4e7ddfc80c5a6318e3a815623c6f99e1a607f4fe614e71c4159ce1004093d)

### Step 4 — Callback Contract

Deploy the callback contract on Ethereum Sepolia, using the Uniswap V2 router at `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`. You should also pass your wallet address as the owner and the Sepolia callback proxy address. Assign the `Deployed to` address from the response to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-take-profit-order/UniswapDemoStopTakeProfitCallback.sol:UniswapDemoStopTakeProfitCallback --value 0.02ether --constructor-args $USER_WALLET $DESTINATION_CALLBACK_PROXY_ADDR 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008
```

Blockchain Explorer: [Callback Contract Deployment](https://sepolia.etherscan.io/tx/0x2a68397f11c079b114ca03be74089a4752251fd487c5e509faaa95fff6ece1f0) | [Contract Address](https://sepolia.etherscan.io/address/0x2EB1e67c17a55A56D6e4fe325859d270132E66EF)

### Step 5 — Reactive Contract

Deploy the Reactive contract specifying your wallet address as the owner and the callback contract address from Step 4. Assign the `Deployed to` address to `REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-stop-take-profit-order/UniswapDemoStopTakeProfitReactive.sol:UniswapDemoStopTakeProfitReactive --value 0.1ether --constructor-args $USER_WALLET $CALLBACK_ADDR
```

Blockchain Explorer: [Reactive Contract Deployment](https://lasna.reactscan.net/tx/0x0c149f62714d75cfeb15739c8e563959598a18eb950650533b824ad4d3706374) | [Contract Address](https://lasna.reactscan.net/address/0x49abe186a9b24f73e34ccae3d179299440c352ac/contract/0x9DC1d0Bb6cBE87e6e53104310ABa0E33ceF76833)

### Step 6 — Authorize Token Spending

Authorize the callback contract to spend your tokens. The last parameter specifies the amount to approve. For tokens with 18 decimals, the example below authorizes the callback contract to spend one token:

```bash
cast send $TOKEN0 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000
```

Blockchain Explorer: [Approve TK1 Transaction](https://sepolia.etherscan.io/tx/0x2a1ca4d95abdc95b8b9e0da443d0fef7b87ab07d05f1627ffc67bd6c40ee4b7f)

### Step 7 — Create a Stop-Loss Order

Create a stop-loss order that will sell `token0` for `token1` when the price drops below a threshold. The parameters are:

- `UNISWAP_V2_PAIR_ADDR`: The pair address from Step 2.
- `SELL_TOKEN0`: `true` to sell `token0`, `false` to sell `token1`.
- `AMOUNT`: Amount of tokens to sell (in wei).
- `COEFFICIENT`: Price calculation coefficient (typically `10000` for 4 decimal precision).
- `THRESHOLD`: Price threshold that triggers the order.
- `ORDER_TYPE`: `0` for stop-loss, `1` for take-profit.

Example creating a stop-loss order:

```bash
cast send $CALLBACK_ADDR 'createStopOrder(address,bool,uint256,uint256,uint256,uint8)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR true 1000000000000000000 10000 8000 0
```

This creates a stop-loss order to sell 1 token0 when the price drops to 0.8 (8000/10000).

Blockchain Explorer: [Create Stop-Loss Order](https://sepolia.etherscan.io/tx/0x94a4f2fe34dd139db09cc407d4b33dffea6f430cf2ebec703efcb24f869dd708)

### Step 8 — Create a Take-Profit Order

Similarly, create a take-profit order that will sell when the price rises above a threshold:

```bash
cast send $CALLBACK_ADDR 'createStopOrder(address,bool,uint256,uint256,uint256,uint8)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR true 1000000000000000000 10000 12000 1
```

This creates a take-profit order to sell 1 token0 when the price rises to 1.2 (12000/10000).

Blockchain Explorer: [Create Take-Profit Order](https://sepolia.etherscan.io/tx/0x8cd7fdf2448e9addb93b5aee9809cf4cb6af37bb5cdb8e540b3e954aac7e0efd)

### Step 9 — Trigger Order Execution

To trigger the orders, adjust the exchange rate by performing swaps directly through the pair. Transfer tokens to the pair:

```bash
cast send $TOKEN0 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 20000000000000000
```

Execute a swap to change the price:

```bash
cast send $UNISWAP_V2_PAIR_ADDR 'swap(uint,uint,address,bytes calldata)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0 5000000000000000 $USER_WALLET "0x"
```

Blockchain Explorer (Stop-Loss trigger — price down): [Transfer TK1 to Pair](https://sepolia.etherscan.io/tx/0x034e91220546bf5fc0d73e61eb12ece501348e7fb00888718db4202dc1de3d20) | [Swap Transaction](https://sepolia.etherscan.io/tx/0xc37600c4543a751d2ca6dedd9516f581a956159c17bf2795e6e419572d63e862)

Blockchain Explorer (Take-Profit trigger — price up): [Transfer TK2 to Pair](https://sepolia.etherscan.io/tx/0x64342d1e0bead48ad9210d3504998897890e8626122a216f523c284fa32cfc29) | [Swap Transaction](https://sepolia.etherscan.io/tx/0x9d9f3daca25b4c8fedf213fbaad7cc13bb7e400cce2ffd69dee7247ad79f78a5)

The reactive contract will detect the price change and automatically trigger the appropriate orders. The execution will be visible on [Sepolia scan](https://sepolia.etherscan.io/).

### Step 10 — Managing Orders

You can pause, resume, or cancel orders using the callback contract:

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

View all orders:
```bash
cast call $CALLBACK_ADDR 'getAllOrders()' --rpc-url $DESTINATION_RPC
```

View active orders:
```bash
cast call $CALLBACK_ADDR 'getActiveOrders()' --rpc-url $DESTINATION_RPC
```