# Reactive Cron

## Overview

This contract acts as a simple template for setting up automated logic on the Reactive Network. It listens for periodic CRON events, making it ideal for scheduling on-chain tasks such as maintenance routines, rewards distribution, or data polling.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `CRON_TOPIC` — An event enabling time-based automation at fixed block intervals (see [Reactive Docs](https://dev.reactive.network/reactive-library#cron-functionality)).

> ⚠️ **Broadcast Error**
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

---

## Key Features

The contract extends `AbstractPausableReactive`, which automatically wires up pause/resume support and handles safe unsubscription. Implementing `getPausableSubscriptions()` allows Reactive to manage this contract's active state without redeployment.

On each CRON event, the contract emits a `Callback`, instructing the Reactive system contract to call the `callback(address)` function. You can customize this to point at another contract or trigger internal automation. The `react()` function filters log records by topic to ensure it only responds to the configured CRON topic.

---

## System Workflow

### How It Works — End-to-End Flow

```
Reactive Network emits a CRON event at a fixed block interval (configured via CRON_TOPIC)
            ↓
BasicCronContract receives the CRON event in its react() function
            ↓
react() verifies the topic matches the configured CRON_TOPIC
            ↓ (if match)
BasicCronContract emits a Callback event with the target function payload
            ↓
Reactive Network's system contract forwards the callback to the designated destination address
            ↓
Destination contract executes the scheduled on-chain logic (e.g. distribute rewards, poll data, run maintenance)
            ↓
Process repeats on the next CRON tick (every N blocks, depending on CRON_TOPIC)
```

### Key Design Decisions

- **Topic-based scheduling**: Different `CRON_TOPIC` values correspond to different intervals (e.g., every block, every minute, every 5 minutes). Choose the topic matching your desired frequency from the [Reactive Docs](https://dev.reactive.network/reactive-library#cron-functionality).
- **Pausable by design**: The contract inherits `AbstractPausableReactive`, meaning you can pause and resume the schedule without redeployment. This is useful for maintenance windows or conditional automation.
- **Customizable callback target**: By default the contract calls `callback(address)` on itself, but you can modify it to point to any external contract — making this a reusable cron trigger for your entire protocol.
- **No state carried between ticks**: Each CRON event is handled independently. If you need stateful logic between ticks, maintain that state in your destination contract.

### CRON Topic Reference

| Interval | Description |
|----------|-------------|
| CRON_1   | ~1 minute   |
| CRON_5   | ~5 minutes  |
| CRON_15  | ~15 minutes |

Refer to the [Reactive Docs](https://dev.reactive.network/reactive-library#cron-functionality) for full topic values.

---

## Step-by-Step Walkthrough

### Phase 1: Configure Environment

**Step 0 — Set your CRON topic**

Choose an interval and export the corresponding topic hash. Example for 1-minute intervals:
```bash
export CRON_TOPIC=<CRON_TOPIC_HASH_FROM_REACTIVE_DOCS>
```

---

### Phase 2: Deploy the Contract

**Step 1 — Deploy BasicCronContract on the Reactive Network**

Pass the CRON topic as the constructor argument. Assign `Deployed to` to `REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/cron/CronDemo.sol:BasicCronContract --value 0.1ether --constructor-args $CRON_TOPIC
```

The contract is now live and listening for CRON events at the chosen interval. No further setup is required for the basic demo — automated callbacks will begin firing each time the CRON topic is emitted by the Reactive Network.


---

### Phase 3: Manage the Schedule

**Step 2 (Optional) — Pause the CRON subscription**

Stops the contract from responding to future CRON events without undeploying it:
```bash
cast send $REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

**Resume the CRON subscription**

Re-enables the contract to respond to CRON events:
```bash
cast send $REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```