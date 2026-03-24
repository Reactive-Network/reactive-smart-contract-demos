# Uniswap V2 Stop-Loss & Take-Profit Orders

## Overview

The **Uniswap V2 Stop-Loss & Take-Profit Orders** system implements a personal reactive smart contract that automatically executes trades on Uniswap V2 when predefined price thresholds are reached. Each user deploys their own instance for complete control and privacy over their stop-loss and take-profit orders. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts that respond to real-time events.

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

---

## Contracts

**Reactive Contract**: [UniswapDemoStopTakeProfitReactive](./UniswapDemoStopTakeProfitReactive.sol) monitors a Uniswap V2 pair's `Sync` events via `UNISWAP_V2_SYNC_TOPIC_0` on Ethereum Sepolia. It tracks user-created stop-loss and take-profit orders by subscribing to lifecycle events (`StopOrderCreated`, `StopOrderCancelled`, `StopOrderExecuted`, `StopOrderPaused`, `StopOrderResumed`) emitted by the callback contract. When reserve changes indicate that a price threshold has been crossed, the contract emits a `Callback` event to trigger order execution. The contract dynamically subscribes to pairs when the first order is created and unsubscribes when all orders for a pair are completed or cancelled, optimizing gas usage.

**Origin/Destination Chain Contract**: [UniswapDemoStopTakeProfitCallback](./UniswapDemoStopTakeProfitCallback.sol) manages the creation and execution of stop-loss and take-profit orders. Users create orders specifying the pair, direction, amount, and price threshold. When triggered by the Reactive Network, the callback contract performs a final on-chain price verification, transfers tokens from the user's wallet, executes the swap through the Uniswap V2 router, and returns the purchased tokens to the user. The contract includes retry logic, pausable orders, and emergency rescue functions for stuck funds. Each user deploys their own instance for isolated order management and complete control over their trading strategy.

**Rescuable Base Contract**: [RescuableBase](./RescuableBase.sol) provides emergency rescue functionality for ETH and ERC20 tokens that may become stuck in the callback contract. This abstract contract allows the owner to recover funds with specific amounts or full balances through safe transfer mechanisms.

---

## System Workflow

### How It Works — End-to-End Flow

```
User creates order on Callback Contract (Sepolia)
            ↓
Callback Contract emits StopOrderCreated event
            ↓
Reactive Contract (Reactive Network) detects event → subscribes to the Uniswap V2 Pair's Sync events
            ↓
Uniswap V2 Pair emits Sync event on every swap/liquidity change
            ↓
Reactive Contract checks: has the price crossed the threshold?
            ↓ (if YES)
Reactive Contract emits Callback event → Reactive Network calls executeOrder() on Callback Contract
            ↓
Callback Contract verifies price on-chain, pulls tokens from user wallet, executes swap via Uniswap V2 Router
            ↓
Purchased tokens sent back to user wallet
            ↓
Callback Contract emits StopOrderExecuted event
            ↓
Reactive Contract receives event → unsubscribes from pair if no more active orders
```

### Key Design Decisions

- **Per-user deployment**: Each user deploys their own Callback contract for full isolation and privacy.
- **Dynamic subscriptions**: The Reactive contract only listens to pairs that have active orders, saving gas.
- **On-chain price verification**: Even after the Reactive layer triggers execution, the Callback contract independently verifies the price before swapping — protecting against stale triggers.
- **Retry logic**: If execution fails (e.g., slippage), the order stays active and can be retried on the next price event.

---

## Step-by-Step Walkthrough

### Phase 1: Setup Infrastructure

**Step 1 — Get test tokens and note token addresses**

Either use the pre-existing test tokens:
```bash
export TOKEN0=0x2AFDE4A3Bca17E830c476c568014E595EA916a04
export TOKEN1=0x7EB2Ad352369bb6EDEb84D110657f2e40c912c95
```

Or deploy your own ERC-20 tokens (each mints 100 units to the deployer):
```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args TK1 TK1
```

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args TK2 TK2
```

---

**Step 2 — Create or export the Uniswap V2 Pair**

Use the pre-existing pair:
```bash
export UNISWAP_V2_PAIR_ADDR=0x1DD11fD3690979f2602E42e7bBF68A19040E2e25
```

Or create a new pair via the Uniswap V2 Factory (`0x7E0987E5b3a30e3f2828572Bb659A548460a3003`):
```bash
cast send 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 'createPair(address,address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $TOKEN0 $TOKEN1
```

> 📝 **Note**: The token with the smaller hexadecimal address becomes `token0`; the other is `token1`.

---

**Step 3 — Add liquidity to the pool**

Transfer TOKEN0 into the pair:
```bash
cast send $TOKEN0 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

Transfer TOKEN1 into the pair:
```bash
cast send $TOKEN1 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

Mint LP tokens to your wallet:
```bash
cast send $UNISWAP_V2_PAIR_ADDR 'mint(address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $USER_WALLET
```

---

### Phase 2: Deploy Contracts

**Step 4 — Deploy the Callback Contract on Sepolia**

Uses Uniswap V2 router at `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`. Assign `Deployed to` to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-take-profit-order/UniswapDemoStopTakeProfitCallback.sol:UniswapDemoStopTakeProfitCallback --value 0.02ether --constructor-args $USER_WALLET $DESTINATION_CALLBACK_PROXY_ADDR 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008
```

---

**Step 5 — Deploy the Reactive Contract on Reactive Network**

Assign `Deployed to` to `REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-stop-take-profit-order/UniswapDemoStopTakeProfitReactive.sol:UniswapDemoStopTakeProfitReactive --value 0.1ether --constructor-args $USER_WALLET $CALLBACK_ADDR
```

---

### Phase 3: Authorize & Create Orders

**Step 6 — Authorize token spending**

Allow the Callback contract to pull tokens from your wallet when executing orders:
```bash
cast send $TOKEN0 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000
```

---

**Step 7 — Create a Stop-Loss Order**

Parameters:
- `pair`: Uniswap V2 pair address
- `sellToken0`: `true` to sell token0, `false` to sell token1
- `amount`: Amount in wei to sell
- `coefficient`: Precision factor (typically `10000`)
- `threshold`: Price threshold × coefficient (e.g., `8000` = price of 0.8 when coefficient = 10000)
- `orderType`: `0` = stop-loss

```bash
cast send $CALLBACK_ADDR 'createStopOrder(address,bool,uint256,uint256,uint256,uint8)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR true 1000000000000000000 10000 8000 0
```

*This creates a stop-loss order to sell 1 token0 when the price drops to 0.8.*

---

**Step 8 — Create a Take-Profit Order**

Same parameters as above, but `orderType` = `1` and threshold above current price:
```bash
cast send $CALLBACK_ADDR 'createStopOrder(address,bool,uint256,uint256,uint256,uint8)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR true 1000000000000000000 10000 12000 1
```

*This creates a take-profit order to sell 1 token0 when the price rises to 1.2.*

---

### Phase 4: Trigger & Verify Execution

**Step 9 — Move the price to trigger order execution**

Transfer tokens directly into the pair to shift reserves:
```bash
cast send $TOKEN0 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 20000000000000000
```

Execute an imbalanced swap to move the price:
```bash
cast send $UNISWAP_V2_PAIR_ADDR 'swap(uint,uint,address,bytes calldata)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0 5000000000000000 $USER_WALLET "0x"
```

The `Sync` event emitted by this swap is detected by the Reactive Contract. If the new price crosses your threshold, the order executes automatically within a few blocks.


---

### Phase 5: Managing Orders

**Step 10 — Pause an order**
```bash
cast send $CALLBACK_ADDR 'pauseStopOrder(uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0
```

**Resume a paused order**
```bash
cast send $CALLBACK_ADDR 'resumeStopOrder(uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0
```

**Cancel an order permanently**
```bash
cast send $CALLBACK_ADDR 'cancelStopOrder(uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0
```

**View all orders (read-only)**
```bash
cast call $CALLBACK_ADDR 'getAllOrders()' --rpc-url $DESTINATION_RPC
```

**View active orders only (read-only)**
```bash
cast call $CALLBACK_ADDR 'getActiveOrders()' --rpc-url $DESTINATION_RPC
```

---

## Further Considerations

The demo showcases essential stop-loss and take-profit functionality but can be improved with:

- **Advanced Order Types:** Supporting trailing stops, conditional orders, and time-based constraints.
- **Multi-Pair Order Management:** Aggregating orders across multiple pairs for unified portfolio management.
- **Slippage Protection:** Adding configurable slippage limits to prevent unfavorable execution prices.
- **Gas Optimization:** Batching order execution and reducing storage costs for large order volumes.
- **Support for Arbitrary DEXes:** Extending functionality to work with Uniswap V3, SushiSwap, and other decentralized exchanges.