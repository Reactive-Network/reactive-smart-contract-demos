# Aave Liquidation Protection Demo

## Overview

The **Aave Liquidation Protection Demo** implements a reactive smart contract system that monitors user positions in Aave lending pools. When a position's health factor drops below a predefined threshold, the system automatically supplies additional collateral to protect the position from liquidation. This demo demonstrates how reactive smart contracts can provide automated risk management for DeFi lending protocols.

## Contracts

**Reactive Contract**: [AaveLiquidationProtectionReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/aave-liquidation-protection/AaveLiquidationProtectionReactive.sol) subscribes to CRON events to periodically check user positions and to `PositionProtected` events from the callback contract. When triggered by a CRON event, it evaluates whether intervention is needed and emits a `Callback` event to initiate protection. The contract uses a triggered flag to prevent duplicate protection attempts and resets after successful execution. It extends `AbstractPausableReactive` for pause/resume functionality.

**Origin/Destination Chain Contract**: [AaveLiquidationProtectionCallback](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/aave-liquidation-protection/AaveLiquidationProtectionCallback.sol) processes liquidation protection requests. When triggered by the Reactive Network, it verifies the caller, checks the user's current health factor against the threshold, calculates the required collateral amount using Chainlink price feeds, transfers collateral from the user's wallet, and supplies it to the Aave lending pool. The contract emits `PositionProtected` events on success or `ProtectionFailed` events with reasons on failure.

## Further Considerations

The demo showcases essential liquidation protection functionality but can be improved with:

- **Multi-Collateral Support:** Accepting various collateral types beyond a single token.
- **Dynamic Health Factor Management:** Adjusting thresholds based on market volatility.
- **Gas Optimization:** Implementing more efficient calculation methods.
- **Emergency Withdrawal:** Adding mechanisms for users to pause protection or withdraw approved tokens.
- **Multi-User Support:** Extending the reactive contract to monitor multiple users simultaneously.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `DESTINATION_RPC` — RPC URL for the destination chain (see [Chainlist](https://chainlist.org)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `DESTINATION_CALLBACK_PROXY_ADDR` — The service address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
* `SYSTEM_CONTRACT_ADDR` — The service address on the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet#overview)).
* `CRON_TOPIC` — An event enabling time-based automation at fixed block intervals (see [Reactive Docs](https://dev.reactive.network/reactive-library#cron-functionality)).
* `USER_WALLET` — The wallet address whose Aave position will be protected.

> ℹ️ **Reactive Faucet on Sepolia**  
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/5, meaning you get 5 REACT for every 1 SepETH sent.

> ⚠️ **Broadcast Error**  
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

### Step 1 — Aave Configuration

Export the required Aave protocol addresses on your destination chain:

```bash
export LENDING_POOL=0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951
export COLLATERAL_TOKEN=0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5
export COLLATERAL_PRICE_FEED=0xc59E3633BAAC79493d908e63626716e204A45EdF
export PROTOCOL_DATA_PROVIDER=0x3e9708d80f7B3e43118013075F7e95CE3AB31F31
```

> 📝 **Note**  
> These addresses are for Aave V3 on Ethereum Sepolia Testnet and `COLLATERAL_TOKEN` as Link Token and `COLLATERAL_PRICE_FEED` is for LINK/USD on Sepolia Testnet.
For other networks or Aave deployments, refer to the [Aave documentation](https://docs.aave.com/developers/deployed-contracts).

### Step 2 — Protection Parameters

Define the protection parameters:

```bash
export HEALTH_FACTOR_THRESHOLD=1200000000000000000  # 1.2 (18 decimals)
export TARGET_HEALTH_FACTOR=1500000000000000000     # 1.5 (18 decimals)
```

### Step 3 — Destination Contract

Deploy the callback contract on the destination chain. Assign the `Deployed to` address from the response to `CALLBACK_ADDR`:

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/aave-liquidation-protection/AaveDemoLiquidationProtectionCallback.sol:AaveLiquidationProtectionCallback --value 0.01ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR $COLLATERAL_TOKEN $COLLATERAL_PRICE_FEED $PROTOCOL_DATA_PROVIDER
```

### Step 4 — Reactive Contract

Deploy the Reactive contract specifying all required parameters:

```bash
forge create --legacy --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/aave-liquidation-protection/AaveDemoLiquidationProtectionReactive.sol:AaveLiquidationProtectionReactive --value 0.01ether --constructor-args $LENDING_POOL $CALLBACK_ADDR $SYSTEM_CONTRACT_ADDR $CRON_TOPIC $USER_WALLET $HEALTH_FACTOR_THRESHOLD $TARGET_HEALTH_FACTOR
```

### Step 5 — Authorize Collateral Spending

The user must authorize the callback contract to spend their collateral tokens. The amount should be sufficient to cover potential protection needs. For tokens with 18 decimals, the example below authorizes 10 tokens:

```bash
cast send $COLLATERAL_TOKEN 'approve(address,uint256)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $CALLBACK_ADDR 10000000000000000000
```

### Step 6 — Create an Aave Position (Optional)

If you need to create a test position:

1. Supply collateral to Aave:
```bash
cast send $LENDING_POOL 'supply(address,uint256,address,uint16)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $COLLATERAL_TOKEN 5000000000000000000 $USER_WALLET 0
```

2. Borrow against the collateral:
```bash
cast send $LENDING_POOL 'borrow(address,uint256,uint256,uint16,address)' --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $BORROW_TOKEN 1000000000000000000 2 0 $USER_WALLET
```

### Step 7 — Monitor Protection

The reactive contract will automatically monitor the position based on the configured CRON interval. Protection events can be viewed on the destination contract's event log on [Sepolia scan](https://sepolia.etherscan.io/).

### Step 8 — Pause/Resume Protection (Optional)

To pause the protection monitoring:

```bash
cast send --legacy $REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume protection:

```bash
cast send --legacy $REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```