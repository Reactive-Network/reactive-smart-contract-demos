# Aave Liquidation Protection Demo

## Overview

The **Aave Liquidation Protection Demo** implements a reactive smart contract that monitors user positions on Aave protocol through periodic CRON events. When a user's health factor drops below a predefined threshold, the contract automatically executes protection measures by either depositing additional collateral or repaying debt to prevent liquidation. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts that respond to real-time events.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `DESTINATION_RPC` — RPC URL for the destination chain (Ethereum Sepolia) (see [Chainlist](https://chainlist.org)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `DESTINATION_CALLBACK_PROXY_ADDR` — The service address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
* `OWNER_WALLET` — The wallet address that will own and manage the protection system.
* `AAVE_LENDING_POOL` — Aave V3 Lending Pool address on Sepolia: `0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951`
* `AAVE_PROTOCOL_DATA_PROVIDER` — Aave V3 Protocol Data Provider on Sepolia: `0x3e9708d80f7B3e43118013075F7e95CE3AB31F31`
* `AAVE_ADDRESSES_PROVIDER` — Aave V3 Pool Addresses Provider on Sepolia: `0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A`

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

**Reactive Contract**: [AaveProtectionDemoReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/aave-liquidation-protection/AaveProtectionDemoReactive.sol) subscribes to CRON events on the Reactive Network and protection lifecycle events from the callback contract on Ethereum Sepolia. It continuously monitors protection configurations and triggers periodic health checks. When the CRON event fires, it calls the callback contract to check and protect all active configurations. The contract tracks protection status through events emitted by the callback contract, including `ProtectionConfigured`, `ProtectionExecuted`, `ProtectionCancelled`, `ProtectionPaused`, `ProtectionResumed`, and `ProtectionCycleCompleted`. This contract demonstrates a simple reactive approach to automated liquidation protection on Aave.

**Origin/Destination Chain Contract**: [AaveProtectionDemoCallback](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/aave-liquidation-protection/AaveProtectionDemoCallback.sol) processes liquidation protection requests. When the Reactive Network triggers the callback via CRON, the contract checks all active protection configurations, queries the user's health factor from Aave, and executes protection measures if needed. The contract supports three protection types: collateral deposit, debt repayment, or both. It calculates the exact amount needed to reach the target health factor and executes the appropriate action through Aave's lending pool. After execution, the contract emits events that the reactive contract monitors to track protection status. The personal callback contract provides complete control and privacy for individual users.

**Rescuable Base Contract**: [RescuableBase](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/aave-liquidation-protection/RescuableBase.sol) is an abstract contract providing rescue functionality for ETH and ERC20 tokens. It allows the owner to recover any stuck funds from the callback contract, with built-in safety checks and event emissions for transparency.

---

## System Workflow

### How It Works — End-to-End Flow

```
User supplies collateral and borrows from Aave (active lending position)
            ↓
User creates a protection config on the Callback Contract (health factor threshold + target + protection type)
            ↓
User approves Callback Contract to spend collateral and/or debt assets
            ↓
Reactive Contract deployed with CRON topic → begins subscribing to periodic CRON events
            ↓
Reactive Network emits CRON event at configured interval (e.g. every 1 minute)
            ↓
Reactive Contract receives CRON event → emits Callback targeting Callback Contract
            ↓
Reactive Network calls checkAndProtect() on Callback Contract (Sepolia)
            ↓
Callback Contract queries user's health factor from Aave Protocol Data Provider
            ↓ (health factor ≥ threshold)
No action taken → Callback Contract emits ProtectionCycleCompleted → wait for next CRON
            ↓ (health factor < threshold)
Callback Contract calculates required protection amount to reach target health factor
            ↓
Executes protection: deposits collateral to Aave and/or repays debt (per config)
            ↓
Callback Contract emits ProtectionExecuted event
            ↓
Reactive Contract detects event → updates protection status → continues monitoring
```

### Protection Types

| Type | Value | Description | When to Use |
|------|-------|-------------|-------------|
| Collateral Deposit | `0` | Deposits additional collateral to raise health factor | You have spare collateral and want to keep your debt |
| Debt Repayment | `1` | Repays part of debt to raise health factor | You want to reduce debt exposure |
| Both | `2` | Attempts preferred method, falls back to alternative | Maximum flexibility |

### Key Design Decisions

- **CRON-based polling**: Rather than waiting for a specific on-chain event, the system actively polls your health factor on each CRON tick. This is necessary because Aave positions can degrade due to market price movements rather than on-chain user actions.
- **On-chain health factor query**: The Callback contract reads health factor directly from Aave's Protocol Data Provider on each check — always using the latest state, never relying on stale cached values.
- **Per-user deployment**: Each user deploys their own Callback contract for complete isolation and privacy over their protection configuration.
- **Dual-asset approval pattern**: The Callback contract needs approval for both collateral and debt assets up front, enabling it to act autonomously when health factor drops.
- **Graceful lifecycle events**: The Reactive contract tracks `ProtectionConfigured`, `ProtectionPaused`, `ProtectionResumed`, `ProtectionCancelled`, and `ProtectionExecuted` events — allowing it to accurately maintain protection state without redeployment.

---

## Step-by-Step Walkthrough

### Phase 1: Setup Aave Position

**Step 1 — Get testnet tokens from the Aave faucet**

Visit the [Aave V3 Testnet Faucet](https://staging.aave.com/faucet/) and request test tokens.

Configure your chosen assets:
```bash
export COLLATERAL_ASSET=0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8  # USDC on Sepolia
export DEBT_ASSET=0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357      # DAI on Sepolia
```


---

**Step 2 — Deploy the Callback Contract on Sepolia**

Pass owner wallet, callback proxy, and the three Aave V3 addresses. Assign `Deployed to` to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/aave-liquidation-protection/AaveProtectionDemoCallback.sol:AaveProtectionDemoCallback --value 0.02ether --constructor-args $OWNER_WALLET $DESTINATION_CALLBACK_PROXY_ADDR $AAVE_LENDING_POOL $AAVE_PROTOCOL_DATA_PROVIDER $AAVE_ADDRESSES_PROVIDER
```

---

**Step 3 — Supply collateral to Aave**

Approve the Aave lending pool to spend your collateral:
```bash
cast send $COLLATERAL_ASSET 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $AAVE_LENDING_POOL 100000000000000000000
```

Supply collateral:
```bash
cast send $AAVE_LENDING_POOL 'supply(address,uint256,address,uint16)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $COLLATERAL_ASSET 50000000000000000000 $OWNER_WALLET 0
```

---

**Step 4 — Borrow from Aave**

Borrow against your collateral using variable rate (mode = `2`):
```bash
cast send $AAVE_LENDING_POOL 'borrow(address,uint256,uint256,uint16,address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $DEBT_ASSET 10000000000000000000 2 0 $OWNER_WALLET
```

You now have an active Aave lending position that this system will protect.

---

### Phase 2: Deploy Reactive Contract

**Step 5 — Deploy AaveProtectionDemoReactive on the Reactive Network**

Choose a CRON topic for your monitoring interval (see [Reactive Docs](https://dev.reactive.network) for available topics):

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/aave-liquidation-protection/AaveProtectionDemoReactive.sol:AaveProtectionDemoReactive --value 0.5ether --constructor-args $OWNER_WALLET $CALLBACK_ADDR $CRON_TOPIC
```

---

### Phase 3: Configure Protection

**Step 6 — Create a protection configuration**

Example: Protection Type `2` (Both), threshold `1.5`, target `2.0`, prefer debt repayment:

```bash
cast send $CALLBACK_ADDR 'createProtectionConfig(uint8,uint256,uint256,address,address,bool)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 2 1500000000000000000 2000000000000000000 $COLLATERAL_ASSET $DEBT_ASSET true
```

---

**Step 7 — Approve protection assets**

Allow the Callback contract to pull funds from your wallet when protection triggers:

Approve collateral asset:
```bash
cast send $COLLATERAL_ASSET 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000000
```

Approve debt asset:
```bash
cast send $DEBT_ASSET 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000000
```

The system is now fully active. From this point, every CRON tick will trigger an automatic health factor check. No further user action is required unless you want to modify the configuration.


---

### Phase 4: Test Protection (Optional)

**Step 8 — Lower your health factor to trigger protection**

Borrow more to reduce the health factor below your configured threshold:
```bash
cast send $AAVE_LENDING_POOL 'borrow(address,uint256,uint256,uint16,address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $DEBT_ASSET 5000000000000000000 2 0 $OWNER_WALLET
```

Wait for the next CRON tick. The Callback contract will detect the health factor has crossed the threshold and automatically execute protection.


---

### Phase 5: Read Current State

**Check current health factor (read-only)**
```bash
cast call $CALLBACK_ADDR 'getCurrentHealthFactor()' --rpc-url $DESTINATION_RPC
```

**View all active configurations (read-only)**
```bash
cast call $CALLBACK_ADDR 'getActiveConfigs()' --rpc-url $DESTINATION_RPC
```

**View a specific protection configuration (read-only)**
```bash
cast call $CALLBACK_ADDR 'protectionConfigs(uint256)' $CONFIG_ID --rpc-url $DESTINATION_RPC
```

---

## Management Functions

### Pause a Protection Configuration

Stops the configuration from executing on future CRON ticks (does not cancel it):
```bash
cast send $CALLBACK_ADDR 'pauseProtectionConfig(uint256)' $CONFIG_ID --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

### Resume a Protection Configuration

```bash
cast send $CALLBACK_ADDR 'resumeProtectionConfig(uint256)' $CONFIG_ID --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

### Cancel a Protection Configuration Permanently

```bash
cast send $CALLBACK_ADDR 'cancelProtectionConfig(uint256)' $CONFIG_ID --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

### Rescue Stuck Funds

If funds get stuck in the callback contract:

Rescue ETH:
```bash
cast send $CALLBACK_ADDR 'rescueAllETH()' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

Rescue ERC20 tokens:
```bash
cast send $CALLBACK_ADDR 'rescueAllERC20(address)' $TOKEN_ADDRESS --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

---

## Further Considerations

The demo showcases essential liquidation protection functionality but can be improved with:

- **Multiple User Support:** Extending to support multiple users with a single contract deployment.
- **Advanced Health Factor Calculations:** Implementing more sophisticated health factor prediction models.
- **Gas Optimization:** Optimizing gas usage for protection execution and batch operations.
- **Emergency Stop Mechanisms:** Adding circuit breakers for emergency situations.
- **Dynamic Protection Strategies:** Supporting time-based or market condition-based protection adjustments.



---

## Supported Assets on Aave V3 Sepolia

| Symbol | Address |
|--------|---------|
| **DAI** | `0xFF34B3d4Aee8ddCd6F9AfffB6Fe49bD371b8a357` |
| **LINK** | `0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5` |
| **USDC** | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` |
| **WBTC** | `0x29f2D40B0605204364af54EC677bD022da425d03` |
| **WETH** | `0xC558DBdD856501FCd9aaF1E62eaE57A9F0629a3C` |
| **USDT** | `0xaA8E23Fb1079EA71e0a56f48a2aA51851D8433D0` |
| **AAVE** | `0x88541670E55cC00bEefd87EB59EDd1b7C511AC9A` |
| **EURS** | `0x6d906e526a4e2Ca02097BA9d0caA3c382f52278E` |
| **GHO** | `0xc4bF5CbDaBE595361438F8c6a187bDC330539c60` |