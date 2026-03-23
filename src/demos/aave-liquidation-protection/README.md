# Aave Liquidation Protection Demo

## Overview

The **Aave Liquidation Protection Demo** implements a reactive smart contract that monitors user positions on Aave protocol through periodic CRON events. When a user's health factor drops below a predefined threshold, the contract automatically executes protection measures by either depositing additional collateral or repaying debt to prevent liquidation. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts that respond to real-time events.

## Contracts

**Reactive Contract**: [AaveProtectionDemoReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/aave-liquidation-protection/AaveProtectionDemoReactive.sol) subscribes to CRON events on the Reactive Network and protection lifecycle events from the callback contract on Ethereum Sepolia. It continuously monitors protection configurations and triggers periodic health checks. When the CRON event fires, it calls the callback contract to check and protect all active configurations. The contract tracks protection status through events emitted by the callback contract, including `ProtectionConfigured`, `ProtectionExecuted`, `ProtectionCancelled`, `ProtectionPaused`, `ProtectionResumed`, and `ProtectionCycleCompleted`. This contract demonstrates a simple reactive approach to automated liquidation protection on Aave.

**Origin/Destination Chain Contract**: [AaveProtectionDemoCallback](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/aave-liquidation-protection/AaveProtectionDemoCallback.sol) processes liquidation protection requests. When the Reactive Network triggers the callback via CRON, the contract checks all active protection configurations, queries the user's health factor from Aave, and executes protection measures if needed. The contract supports three protection types: collateral deposit, debt repayment, or both. It calculates the exact amount needed to reach the target health factor and executes the appropriate action through Aave's lending pool. After execution, the contract emits events that the reactive contract monitors to track protection status. The personal callback contract provides complete control and privacy for individual users.

**Rescuable Base Contract**: [RescuableBase](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/aave-liquidation-protection/RescuableBase.sol) is an abstract contract providing rescue functionality for ETH and ERC20 tokens. It allows the owner to recover any stuck funds from the callback contract, with built-in safety checks and event emissions for transparency.

## Further Considerations

The demo showcases essential liquidation protection functionality but can be improved with:

- **Multiple User Support:** Extending to support multiple users with a single contract deployment.
- **Advanced Health Factor Calculations:** Implementing more sophisticated health factor prediction models.
- **Gas Optimization:** Optimizing gas usage for protection execution and batch operations.
- **Emergency Stop Mechanisms:** Adding circuit breakers for emergency situations.
- **Dynamic Protection Strategies:** Supporting time-based or market condition-based protection adjustments.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `DESTINATION_RPC` — RPC URL for the destination chain (Ethereum Sepolia), (see [Chainlist](https://chainlist.org)).
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

### Step 1 — Aave Test Tokens

To test live, you'll need testnet tokens supported by Aave V3 on Sepolia. Use the Aave faucet to obtain test tokens:

Visit the [Aave V3 Testnet Faucet](https://staging.aave.com/faucet/) and request test tokens.

**Supported Assets on Aave V3 Sepolia:**

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

Example usage:

```bash
export COLLATERAL_ASSET=0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8  # USDC on Sepolia
export DEBT_ASSET=0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357      # DAI on Sepolia
```

### Step 2 — Destination Contract

Deploy the callback contract on Ethereum Sepolia, using the Aave V3 protocol addresses. You should also pass the Sepolia callback proxy address and the owner wallet address. Assign the `Deployed to` address from the response to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/aave-liquidation-protection/AaveProtectionDemoCallback.sol:AaveProtectionDemoCallback --value 0.02ether --constructor-args $OWNER_WALLET $DESTINATION_CALLBACK_PROXY_ADDR $AAVE_LENDING_POOL $AAVE_PROTOCOL_DATA_PROVIDER $AAVE_ADDRESSES_PROVIDER
```

Blockchain Explorer: [Callback Contract Deployment](https://sepolia.etherscan.io/tx/0xd9bbba62aa2591710e0b8f5067a97bdd4c4fedae4ac095f5b6c6ed2fb73135f6) | [Contract Address](https://sepolia.etherscan.io/address/0xF9A6d0f16ce892F7438773cdE2d43B4c0e732A7e)

### Step 3 — Supply Collateral and Borrow on Aave

Before setting up protection, you need to have an active Aave position. Supply collateral and borrow assets:

**Supply Collateral:**

First, approve the Aave lending pool to spend your collateral:

```bash
cast send $COLLATERAL_ASSET 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $AAVE_LENDING_POOL 100000000000000000000
```

Then supply the collateral to Aave:

```bash
cast send $AAVE_LENDING_POOL 'supply(address,uint256,address,uint16)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $COLLATERAL_ASSET 50000000000000000000 $OWNER_WALLET 0
```

Blockchain Explorer: [Approve LINK](https://sepolia.etherscan.io/tx/0x795e683134ea041fbe6accb8932dc4154bda98ed2eda817f3b26aed804e26ea2) | [Supply 50 LINK](https://sepolia.etherscan.io/tx/0xb290b3d2dc78f6bd4351be9f68f5c5e95c98bc3ac6509350dafe19f30670dd8f)

**Borrow Assets:**

Borrow against your collateral (use mode 2 for variable rate):

```bash
cast send $AAVE_LENDING_POOL 'borrow(address,uint256,uint256,uint16,address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $DEBT_ASSET 10000000000000000000 2 0 $OWNER_WALLET
```

Blockchain Explorer: [Borrow 100 EURS](https://sepolia.etherscan.io/tx/0x7f76e00331a7e1afd3168047052fef36274abad0f139a9d3a183e301da1304aa)

### Step 4 — Reactive Contract

Deploy the Reactive contract specifying:

- `OWNER_WALLET`: The wallet address that owns and manages the protection system.
- `CALLBACK_ADDR`: The address from Step 2.
- `CRON_TOPIC`: The CRON topic ID for periodic monitoring (e.g., `0x04463f7c1651e6b9774d7f85c85bb94654e3c46ca79b0c16fb16d4183307b687` for 1-minute intervals).

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/aave-liquidation-protection/AaveProtectionDemoReactive.sol:AaveProtectionDemoReactive --value 0.5ether --constructor-args $OWNER_WALLET $CALLBACK_ADDR $CRON_TOPIC
```

Blockchain Explorer: [Reactive Contract Deployment](https://lasna.reactscan.net/tx/0x6b550eb9cfc992c2b9f8b05cbe2337cf350d322117be67688964e7ae240e44d7) | [Contract Address](https://lasna.reactscan.net/address/0x49abe186a9b24f73e34ccae3d179299440c352ac/contract/0x48d7a91DA7d542F1E1262DA4F9AC920003D77a59)

> 📝 **Note**  
> The CRON topic determines how frequently the reactive contract checks your position. Common intervals:
> - 1 minute: Use the system CRON_1 topic
> - 5 minutes: Use the system CRON_5 topic
> - 15 minutes: Use the system CRON_15 topic
> 
> Check the [Reactive Network Documentation](https://dev.reactive.network) for available CRON topics.

### Step 5 — Create Protection Configuration

Create a protection configuration on the callback contract. You'll need to specify:

- `PROTECTION_TYPE`: Protection type (0 = Collateral Deposit, 1 = Debt Repayment, 2 = Both)
- `HEALTH_FACTOR_THRESHOLD`: Health factor below which protection triggers (e.g., 1.5e18 for 1.5)
- `TARGET_HEALTH_FACTOR`: Target health factor to achieve after protection (e.g., 2.0e18 for 2.0)
- `PREFER_DEBT_REPAYMENT`: If using type 2 (Both), whether to prefer debt repayment (true/false)

```bash
cast send $CALLBACK_ADDR 'createProtectionConfig(uint8,uint256,uint256,address,address,bool)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $PROTECTION_TYPE $HEALTH_FACTOR_THRESHOLD $TARGET_HEALTH_FACTOR $COLLATERAL_ASSET $DEBT_ASSET $PREFER_DEBT_REPAYMENT
```

Example with specific values (Protection Type = Both, Threshold = 1.5, Target = 2.0, Prefer Debt Repayment = true):

```bash
cast send $CALLBACK_ADDR 'createProtectionConfig(uint8,uint256,uint256,address,address,bool)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 2 1500000000000000000 2000000000000000000 $COLLATERAL_ASSET $DEBT_ASSET true
```

Blockchain Explorer: [Create Protection Config](https://sepolia.etherscan.io/tx/0xaaa5f694cb6bdfe4245e3586c108f5742b7e2bd5e37746b98227b109cec7d88a)

### Step 6 — Approve Protection Assets

Authorize the callback contract to spend your collateral and debt assets for protection execution:

**Approve Collateral Asset:**

```bash
cast send $COLLATERAL_ASSET 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000000
```

**Approve Debt Asset:**

```bash
cast send $DEBT_ASSET 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CALLBACK_ADDR 1000000000000000000000
```

Blockchain Explorer: [Approve LINK (collateral)](https://sepolia.etherscan.io/tx/0xca12a1831442a5c1f1b1fb7f121e365d13d540cef030536b3f13010bbdd42628) | [Approve EURS (debt)](https://sepolia.etherscan.io/tx/0x7ad93016d0132952b285027f13d0c3d264b5569af8f025c5664b518454c43c56)

> 📝 **Note**
> These approvals allow the callback contract to pull funds from your wallet when protection is triggered. Ensure you maintain sufficient balance of the required assets in your wallet.

### Step 7 — Monitor Protection

The reactive contract will now automatically monitor your Aave position based on the CRON schedule. When your health factor drops below the threshold, it will:

1. Trigger the callback contract via the Reactive Network
2. The callback contract checks your health factor on Aave
3. If below threshold, it calculates the required protection amount
4. Executes either collateral deposit or debt repayment (or both)
5. Emits events that the reactive contract monitors

You can view the protection execution on [Sepolia scan](https://sepolia.etherscan.io/) by monitoring the callback contract's events.

**Check Current Health Factor:**

```bash
cast call $CALLBACK_ADDR 'getCurrentHealthFactor()' --rpc-url $DESTINATION_RPC
```

**View Active Configurations:**

```bash
cast call $CALLBACK_ADDR 'getActiveConfigs()' --rpc-url $DESTINATION_RPC
```

**View Protection Configuration:**

```bash
cast call $CALLBACK_ADDR 'protectionConfigs(uint256)' $CONFIG_ID --rpc-url $DESTINATION_RPC
```

### Step 8 — Test Protection Trigger (Optional)

To manually test the protection mechanism, you can increase your borrowed amount to lower your health factor:

```bash
cast send $AAVE_LENDING_POOL 'borrow(address,uint256,uint256,uint16,address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $DEBT_ASSET 5000000000000000000 2 0 $OWNER_WALLET
```

Monitor your health factor and watch for the protection to trigger automatically when it drops below your configured threshold.

## Management Functions

### Pause Protection

Temporarily pause a protection configuration:

```bash
cast send $CALLBACK_ADDR 'pauseProtectionConfig(uint256)' $CONFIG_ID --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

### Resume Protection

Resume a paused protection configuration:

```bash
cast send $CALLBACK_ADDR 'resumeProtectionConfig(uint256)' $CONFIG_ID --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

### Cancel Protection

Permanently cancel a protection configuration:

```bash
cast send $CALLBACK_ADDR 'cancelProtectionConfig(uint256)' $CONFIG_ID --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

### Rescue Funds

If funds get stuck in the callback contract, you can rescue them:

**Rescue ETH:**

```bash
cast send $CALLBACK_ADDR 'rescueAllETH()' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

**Rescue ERC20 Tokens:**

```bash
cast send $CALLBACK_ADDR 'rescueAllERC20(address)' $TOKEN_ADDRESS --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

## Architecture

The Aave Liquidation Protection system consists of two main components:

1. **Reactive Contract (on Reactive Network)**: Monitors CRON events and protection lifecycle events, triggering callbacks when needed.

2. **Callback Contract (on Ethereum Sepolia)**: Contains the business logic for checking health factors, calculating protection amounts, and executing Aave interactions.

**Event Flow:**

```
CRON Event → Reactive Contract → Callback on Sepolia → Check Health Factor
                                                      ↓
                                                  If below threshold
                                                      ↓
                                          Calculate Protection Amount
                                                      ↓
                                          Execute Aave Transaction
                                                      ↓
                                          Emit ProtectionExecuted Event
                                                      ↓
                                          Reactive Contract Updates Status
```

## Protection Types

### Collateral Deposit (Type 0)
Deposits additional collateral to increase health factor. Best when you have available collateral assets and want to maintain your debt position.

### Debt Repayment (Type 1)
Repays part of your debt to increase health factor. Best when you want to reduce your debt exposure.

### Both (Type 2)
Attempts both methods based on preference. Provides maximum flexibility by trying the preferred method first and falling back to the alternative if needed.