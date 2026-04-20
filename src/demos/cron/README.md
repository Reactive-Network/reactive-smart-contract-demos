# CRON Demo

## Overview

The **CRON Demo** deploys a Reactive contract that responds to periodic CRON events on Reactive Network. On each CRON tick, the contract records the current block number and emits a `Callback` event that calls back into itself. The pattern serves as a starting template for any time-based automation: rewards distribution, maintenance routines, data polling, or periodic state updates.

The contract extends `AbstractPausableReactive`, which provides built-in pause and resume support. The `getPausableSubscriptions()` method declares the contract's subscriptions, allowing Reactive to manage its active state without redeployment.

## Deployment & Testing

### Environment Variables

Before deploying, set the following environment variables:

* `REACTIVE_RPC` — RPC URL for Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on Reactive Network.
* `CRON_TOPIC` — An event enabling time-based automation at fixed block intervals (see [Reactive Docs](https://dev.reactive.network/reactive-library#cron-functionality)).

> ⚠️ **Broadcast Error**
>
> If you see `error: unexpected argument '--broadcast' found`, your Foundry version does not support the `--broadcast` flag for `forge create`. Remove it from the command and re-run.

### Step 1 — Reactive Contract

Deploy `BasicCronContract` with the desired CRON topic. Save the `Deployed to` address as `REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/cron/CronDemo.sol:BasicCronContract --value 0.1ether --constructor-args $CRON_TOPIC
```

Once deployed, the contract will begin responding to CRON events automatically. Each tick updates `lastCronBlock` and emits a `Callback` event.

### Step 2 — Pause and Resume (Optional)

The contract supports pausing and resuming its CRON subscription without redeployment. To pause:

```bash
cast send $REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume:

```bash
cast send $REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
