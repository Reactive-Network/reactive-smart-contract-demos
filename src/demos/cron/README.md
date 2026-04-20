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

Use one of the following CRON topics depending on the desired interval.

| Event       | Interval            | Approx. time | Topic 0                                                              |
|-------------|---------------------|--------------|----------------------------------------------------------------------|
| `Cron1`     | Every block         | ~7 seconds   | `0xf02d6ea5c22a71cffe930a4523fcb4f129be6c804db50e4202fb4e0b07ccb514` |
| `Cron10`    | Every 10 blocks     | ~1 minute    | `0x04463f7c1651e6b9774d7f85c85bb94654e3c46ca79b0c16fb16d4183307b687` |
| `Cron100`   | Every 100 blocks    | ~12 minutes  | `0xb49937fb8970e19fd46d48f7e3fb00d659deac0347f79cd7cb542f0fc1503c70` |
| `Cron1000`  | Every 1,000 blocks  | ~2 hours     | `0xe20b31294d84c3661ddc8f423abb9c70310d0cf172aa2714ead78029b325e3f4` |
| `Cron10000` | Every 10,000 blocks | ~28 hours    | `0xd214e1d84db704ed42d37f538ea9bf71e44ba28bc1cc088b2f5deca654677a56` |

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
