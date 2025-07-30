# Reactive Cron

## Overview

This contract acts as a simple template for setting up automated logic on the Reactive Network. It listens for periodic CRON events, making it ideal for scheduling on-chain tasks such as maintenance routines, rewards distribution, or data polling.

## Key Features

The contract extends `AbstractPausableReactive`, which automatically wires up pause/resume support and handles safe unsubscription. Implementing `getPausableSubscriptions()` allows Reactive to manage this contract’s active state without redeployment.

On each CRON event, the contract emits a `Callback`, instructing the Reactive system contract to call the `callback(address)` function. You can customize this to point at another contract or trigger internal automation. The `react()` function filters log records by topic to ensure it only responds to the configured CRON topic.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `SYSTEM_CONTRACT_ADDR` — The service address on the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet#overview)).
* `CRON_TOPIC` — An event enabling time-based automation at fixed block intervals (see [Reactive Docs](https://dev.reactive.network/reactive-library#cron-functionality)).

> ⚠️ **Broadcast Error**  
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

### Step 1 — Reactive Contract

Deploy the `BasicCronContract` contract, providing it with the system contract address and the preferred cron topic.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/cron/CronDemo.sol:BasicCronContract --value 0.1ether --constructor-args $SYSTEM_CONTRACT_ADDR $CRON_TOPIC
```

### Step 2 — Cron Pause (Optional)

To pause the cron subscription, run this command:

```bash
cast send $REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the cron subscription, run this command:

```bash
cast send $REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
