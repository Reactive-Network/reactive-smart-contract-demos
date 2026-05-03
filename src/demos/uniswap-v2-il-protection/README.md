# Uniswap V2 IL Protection

## Overview

The **Uniswap V2 IL Protection** system implements a personal reactive smart contract that monitors a user's Uniswap V2 LP position in real time and automatically removes liquidity when the reserve ratio diverges beyond a user-defined impermanent loss threshold. Each user deploys their own instance for complete control and privacy over their LP positions. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic).

## Deployment & Testing

### Environment Variables

```bash
export DESTINATION_RPC=<Sepolia RPC URL>
export DESTINATION_PRIVATE_KEY=<Sepolia private key>
export REACTIVE_RPC=<Reactive Network RPC URL>
export REACTIVE_PRIVATE_KEY=<Reactive Network private key>
export DESTINATION_CALLBACK_PROXY_ADDR=<Callback proxy address on Sepolia>
export USER_WALLET=<Your EOA wallet address>
```

---

## Contracts

**Reactive Contract**: [UniswapV2ILProtectionReactive](./UniswapV2ILProtectionReactive.sol) monitors a Uniswap V2 pair's `Sync` events via `UNISWAP_V2_SYNC_TOPIC_0` on Ethereum Sepolia. It tracks user-registered LP positions by subscribing to lifecycle events (`PositionRegistered`, `PositionCancelled`, `PositionExited`, `PositionPaused`, `PositionResumed`) emitted by the callback contract. On each `Sync` event, the contract computes the reserve-ratio divergence from each position's entry snapshot. When divergence exceeds the position's threshold, it emits a `Callback` event to trigger the exit. The contract dynamically subscribes to pairs when the first position is registered and unsubscribes when all positions for a pair are completed or cancelled.

**Origin/Destination Chain Contract**: [UniswapV2ILProtectionCallback](./UniswapV2ILProtectionCallback.sol) manages the registration and execution of IL protection positions. Users register positions specifying the pair, LP token amount, and divergence threshold. The entry reserve snapshot is taken at registration time. When triggered by the Reactive Network, the callback contract performs a final on-chain divergence check, pulls LP tokens from the user's wallet, removes liquidity through the Uniswap V2 router, and returns token0 and token1 directly to the user. Each user deploys their own instance for isolated position management.

**Rescuable Base Contract**: [RescuableBase](./RescuableBase.sol) provides emergency rescue functionality for ETH and ERC20 tokens that may become stuck in the callback contract.

---

## How IL Divergence is Measured

The system tracks impermanent loss by monitoring the **reserve ratio** of the pair relative to the snapshot taken when the user registered their position.

```
Entry ratio:   R_entry   = entryReserve0 / entryReserve1
Current ratio: R_current = reserve0Now   / reserve1Now

divergenceBps = |R_current - R_entry| / R_entry * 10000
```

To avoid floating-point arithmetic on-chain, this is computed via cross-multiplication:

```
divergenceBps = |currentR0 * entryR1 - entryR0 * currentR1|
                / (entryR0 * currentR1) * 10000
```

The position exits when `divergenceBps >= divergenceThresholdBps`. For example, a threshold of `2000` corresponds to a 20% reserve ratio divergence from entry.

---

## System Workflow

### How It Works — End-to-End Flow

```
User adds liquidity to a Uniswap V2 pair → receives LP tokens
            ↓
User registers a position on the Callback Contract (pair, LP amount, divergence threshold)
Callback Contract records entry reserve snapshot (reserve0, reserve1) at this moment
            ↓
Callback Contract emits PositionRegistered event
            ↓
Reactive Contract (Reactive Network) detects event → subscribes to the pair's Sync events
            ↓
Any swap or liquidity event on the pair emits a Sync event (reserve update)
            ↓
Reactive Contract receives Sync event → computes divergenceBps against each registered position's entry snapshot
            ↓ (divergenceBps < threshold)
No action → continue monitoring on next Sync event
            ↓ (divergenceBps >= threshold)
Reactive Contract emits Callback event → Reactive Network calls exitPosition() on Callback Contract
            ↓
Callback Contract performs final on-chain divergence check
            ↓
Callback Contract pulls LP tokens from user wallet → calls removeLiquidity() on Uniswap V2 Router
            ↓
token0 and token1 returned directly to user wallet
            ↓
Callback Contract emits PositionExited event
            ↓
Reactive Contract detects event → unsubscribes from pair if no more active positions remain
```

### Key Design Decisions

- **Entry snapshot at registration**: The reserve ratio is captured at the exact moment of `registerPosition()`, giving each position its own personal baseline for divergence measurement.
- **Basis points (BPS) for thresholds**: Divergence is expressed in BPS (1 BPS = 0.01%) for precision without floats. A threshold of `2000` = 20% divergence.
- **Cross-multiplication arithmetic**: All divergence math uses integer cross-multiplication to avoid Solidity's lack of native floating-point, keeping computation fully on-chain and deterministic.
- **Dynamic pair subscriptions**: The Reactive contract only subscribes to a pair when it has active positions and unsubscribes once all are exited or cancelled, minimising gas overhead.
- **Final on-chain verification**: Even after the Reactive layer triggers the exit, the Callback contract independently re-checks divergence before executing — protecting against stale or replayed callbacks.
- **Per-user deployment**: Each user deploys their own Callback contract, ensuring full position isolation and no shared state between users.

---

## Step-by-Step Walkthrough

### Phase 1: Setup Tokens & Liquidity

**Step 1 — Deploy or export test tokens**

Use pre-existing tokens:
```bash
export TOKEN0=0x2AFDE4A3Bca17E830c476c568014E595EA916a04
export TOKEN1=0x7EB2Ad352369bb6EDEb84D110657f2e40c912c95
```

Or deploy your own ERC-20 tokens:
```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken \
  --constructor-args TK1 TK1
```

Repeat for the second token with a different name and symbol.

---

**Step 2 — Create or export the Uniswap V2 Pair**

Use an existing pair:
```bash
export UNISWAP_V2_PAIR_ADDR=0x1DD11fD3690979f2602E42e7bBF68A19040E2e25
```

Or create a new pair via the Uniswap V2 Factory (`0x7E0987E5b3a30e3f2828572Bb659A548460a3003`):
```bash
cast send 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 \
  'createPair(address,address)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  $TOKEN0 $TOKEN1
```

Retrieve the pair address from the `PairCreated` event on [Sepolia scan](https://sepolia.etherscan.io/).

---

**Step 3 — Add liquidity to the pool**

Transfer tokens to the pair and mint LP tokens to your wallet:
```bash
cast send $TOKEN0 'transfer(address,uint256)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  $UNISWAP_V2_PAIR_ADDR 10000000000000000000

cast send $TOKEN1 'transfer(address,uint256)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  $UNISWAP_V2_PAIR_ADDR 10000000000000000000

cast send $UNISWAP_V2_PAIR_ADDR 'mint(address)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  $USER_WALLET
```

---

### Phase 2: Deploy Contracts

**Step 4 — Deploy the Callback Contract on Sepolia**

Uses Uniswap V2 router at `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`. Assign `Deployed to` to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  src/demos/uniswap-v2-il-protection/UniswapV2ILProtectionCallback.sol:UniswapV2ILProtectionCallback \
  --value 0.02ether \
  --constructor-args $USER_WALLET $DESTINATION_CALLBACK_PROXY_ADDR 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008
```

---

**Step 5 — Deploy the Reactive Contract on the Reactive Network**

Assign `Deployed to` to `REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY \
  src/demos/uniswap-v2-il-protection/UniswapV2ILProtectionReactive.sol:UniswapV2ILProtectionReactive \
  --value 0.1ether \
  --constructor-args $USER_WALLET $CALLBACK_ADDR
```

---

### Phase 3: Authorize & Register Position

**Step 6 — Approve LP token spending**

Authorize the Callback contract to pull your LP tokens when an exit is triggered:
```bash
cast send $UNISWAP_V2_PAIR_ADDR 'approve(address,uint256)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  $CALLBACK_ADDR 1000000000000000000000
```

---

**Step 7 — Register a position**

Parameters:
- `UNISWAP_V2_PAIR_ADDR` — the pair to protect
- `LP_AMOUNT` — amount of LP tokens to protect (in wei)
- `DIVERGENCE_THRESHOLD_BPS` — divergence threshold in basis points (e.g. `2000` = 20%)

```bash
cast send $CALLBACK_ADDR \
  'registerPosition(address,uint256,uint256)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  $UNISWAP_V2_PAIR_ADDR 1000000000000000000 2000
```

At this moment, the Callback contract records the current reserves as the entry snapshot. The Reactive contract begins subscribing to the pair's `Sync` events and will monitor every subsequent reserve change against this baseline.

---

### Phase 4: Trigger & Verify Exit

**Step 8 — Simulate IL divergence to trigger the exit**

Perform a large imbalanced swap directly on the pair to shift the reserve ratio beyond the threshold:
```bash
cast send $TOKEN0 'transfer(address,uint256)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  $UNISWAP_V2_PAIR_ADDR 5000000000000000000

cast send $UNISWAP_V2_PAIR_ADDR \
  'swap(uint,uint,address,bytes calldata)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  0 2000000000000000000 $USER_WALLET "0x"
```

The `Sync` event from this swap is picked up by the Reactive Contract. If the computed divergence now meets or exceeds the registered threshold, the exit is triggered automatically — LP tokens are pulled from your wallet, liquidity is removed via the Uniswap V2 Router, and token0 + token1 are returned to your wallet. The execution will be visible on [Sepolia scan](https://sepolia.etherscan.io/).

---

### Phase 5: Managing Positions

**Pause a position** (stops execution on future Sync events without cancelling):
```bash
cast send $CALLBACK_ADDR 'pausePosition(uint256)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0
```

**Resume a paused position**:
```bash
cast send $CALLBACK_ADDR 'resumePosition(uint256)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0
```

**Cancel a position permanently**:
```bash
cast send $CALLBACK_ADDR 'cancelPosition(uint256)' \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0
```

**View all positions (read-only)**:
```bash
cast call $CALLBACK_ADDR 'getAllPositions()' --rpc-url $DESTINATION_RPC
```

**View active positions only (read-only)**:
```bash
cast call $CALLBACK_ADDR 'getActivePositions()' --rpc-url $DESTINATION_RPC
```

**Check current divergence for a position (read-only)**:
```bash
cast call $CALLBACK_ADDR 'getCurrentDivergenceBps(uint256)' \
  --rpc-url $DESTINATION_RPC 0
```

---

## Further Considerations

The demo showcases essential IL protection functionality but can be improved with:

- **Slippage Protection:** Adding `amountAMin` / `amountBMin` parameters to `removeLiquidity` to prevent unfavourable execution prices.
- **Partial Exit:** Removing only a fraction of LP tokens when a soft threshold is crossed, with full exit at a hard threshold.
- **Multi-Position Support:** Aggregating multiple LP positions across different pairs under one contract.
- **Re-Entry Logic:** Automatically re-adding liquidity once price returns within range.
- **V3 Support:** Extending to Uniswap V3 concentrated liquidity positions.