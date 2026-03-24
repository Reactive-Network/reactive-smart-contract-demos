# Uniswap V2 Stop Order Demo

## Overview

The **Uniswap V2 Stop Order Demo** implements a reactive smart contract that monitors `Sync` events in a Uniswap V2 liquidity pool. When the exchange rate reaches a predefined threshold, the contract automatically executes asset sales. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts that respond to real-time events.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `DESTINATION_RPC` — RPC URL for the destination chain (see [Chainlist](https://chainlist.org)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `DESTINATION_CALLBACK_PROXY_ADDR` — The service address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
* `CLIENT_WALLET` — Deployer's EOA wallet address.

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

**Token Contract**: [UniswapDemoToken](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol) is a basic ERC-20 token with 100 tokens minted to the deployer's address. It provides integration points for Uniswap swaps.

**Reactive Contract**: [UniswapDemoStopOrderReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderReactive.sol) subscribes to a Uniswap V2 pair's `Sync` events via `UNISWAP_V2_SYNC_TOPIC_0` and a stop-order contract's events via `STOP_ORDER_STOP_TOPIC_0` on Ethereum Sepolia. It continuously monitors the pair's reserves. If the reserves drop below a specified threshold, it triggers a stop order by emitting a `Callback` event containing the necessary parameters. The stop order's corresponding event confirms execution, after which the contract marks the process as complete. This contract demonstrates a simple reactive approach to automated stop-order logic on Uniswap V2 pairs.

**Origin/Destination Chain Contract**: [UniswapDemoStopOrderCallback](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderCallback.sol) processes stop orders. When the Reactive Network triggers the callback, the contract verifies the caller, checks the exchange rate and token balance, and performs the token swap through the Uniswap V2 router, transferring the swapped tokens back to the client. After execution, the contract emits a `Stop` event, signaling the reactive contract to conclude. The stateless callback contract can be used across multiple reactive stop orders with the same router.

---

## System Workflow

### How It Works — End-to-End Flow

```
Reactive Contract deployed with: pair address, threshold, direction, client wallet
            ↓
Reactive Contract subscribes to Sync events from the Uniswap V2 Pair (Sepolia)
            ↓
Any swap or liquidity event causes the Pair to emit a Sync event (reserve update)
            ↓
Reactive Contract receives the Sync event → reads reserve0 and reserve1
            ↓
Reactive Contract computes exchange rate and compares against the configured threshold
            ↓ (if threshold crossed)
Reactive Contract emits Callback event → Reactive Network calls stopOrder() on Callback Contract
            ↓
Callback Contract verifies: correct caller? exchange rate still valid? sufficient token balance?
            ↓ (if all checks pass)
Callback Contract pulls tokens from client wallet → swaps via Uniswap V2 Router → sends output tokens to client
            ↓
Callback Contract emits Stop event
            ↓
Reactive Contract receives Stop event → marks stop order as complete → stops monitoring
```

### Key Design Decisions

- **Stateless Callback Contract**: The Callback contract stores no order state, making it reusable across many Reactive stop orders with the same router.
- **Single-use Reactive Contract**: Each Reactive contract instance represents one stop order. Once the `Stop` event is received, it halts permanently.
- **Direct pair interaction for testing**: Price adjustments bypass the router for precise threshold testing, since the router enforces minimum output constraints.
- **Two-topic subscription**: The Reactive contract listens to both the pair's `Sync` events and the callback contract's `Stop` event, allowing it to self-terminate cleanly after execution.

---

## Step-by-Step Walkthrough

### Phase 1: Setup Tokens & Liquidity

**Step 1 — Deploy or export test tokens**

Use pre-existing tokens:
```bash
export TK1=0x2AFDE4A3Bca17E830c476c568014E595EA916a04
export TK2=0x7EB2Ad352369bb6EDEb84D110657f2e40c912c95
```

Or deploy your own ERC-20 tokens:
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

Or create a new pair via the factory (`0x7E0987E5b3a30e3f2828572Bb659A548460a3003`):
```bash
cast send 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 'createPair(address,address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $TOKEN0_ADDR $TOKEN1_ADDR
```

> 📝 **Note**: The token with the smaller hexadecimal address becomes `token0`; the other is `token1`.

---

### Phase 2: Deploy the Callback Contract

**Step 3 — Deploy UniswapDemoStopOrderCallback on Sepolia**

Uses Uniswap V2 router `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`. Assign `Deployed to` to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderCallback.sol:UniswapDemoStopOrderCallback --value 0.02ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008
```

---

### Phase 3: Add Liquidity

**Step 4 — Fund the pool and mint LP tokens**

Transfer TOKEN0 into the pair:
```bash
cast send $TOKEN0_ADDR 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

Transfer TOKEN1 into the pair:
```bash
cast send $TOKEN1_ADDR 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 10000000000000000000
```

Mint LP tokens to your wallet:
```bash
cast send $UNISWAP_V2_PAIR_ADDR 'mint(address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CLIENT_WALLET
```

---

### Phase 4: Deploy the Reactive Contract

**Step 5 — Deploy UniswapDemoStopOrderReactive on the Reactive Network**

Parameters:
- `UNISWAP_V2_PAIR_ADDR` — the pair to monitor
- `CALLBACK_ADDR` — the callback contract from Step 3
- `CLIENT_WALLET` — wallet that owns the tokens to sell
- `DIRECTION_BOOLEAN` — `true` to sell token0 for token1; `false` for the reverse
- `EXCHANGE_RATE_DENOMINATOR` and `EXCHANGE_RATE_NUMERATOR` — e.g., denominator=`1000`, numerator=`1234` for a threshold of 1.234

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderReactive.sol:UniswapDemoStopOrderReactive --value 0.1ether --constructor-args $UNISWAP_V2_PAIR_ADDR $CALLBACK_ADDR $CLIENT_WALLET $DIRECTION_BOOLEAN $EXCHANGE_RATE_DENOMINATOR $EXCHANGE_RATE_NUMERATOR
```

---

### Phase 5: Authorize Token Spending

**Step 6 — Approve the Callback contract to spend your tokens**

```bash
cast send $TOKEN_ADDR 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000
```

---

### Phase 6: Trigger the Stop Order

**Step 7 — Adjust the exchange rate to cross the threshold**

Send tokens directly to the pair (bypasses the router so the rate shifts without output constraints):
```bash
cast send $TOKEN_ADDR 'transfer(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDR 20000000000000000
```

Execute an imbalanced swap to materially shift the price:
```bash
cast send $UNISWAP_V2_PAIR_ADDR 'swap(uint,uint,address,bytes calldata)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0 5000000000000000 $CLIENT_WALLET "0x"
```

The `Sync` event from this swap is picked up by the Reactive Contract. If the new rate is below the configured threshold, execution is triggered automatically.


---

## Further Considerations

The demo showcases essential stop order functionality but can be improved with:

- **Dynamic Event Subscriptions:** Supporting multiple orders and flexible event handling.
- **Sanity Checks and Retry Policies:** Adding error handling and retry mechanisms.
- **Support for Arbitrary Routers and DEXes:** Extending functionality to work with various routers and decentralized exchanges.
- **Improved Data Flow:** Refining interactions between reactive and destination chain contracts for better reliability.