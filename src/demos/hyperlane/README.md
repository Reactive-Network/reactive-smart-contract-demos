# Hyperlane Demo

## Overview

The **Hyperlane Demo** sets up two-way messaging between Base Mainnet and Reactive Mainnet using the Hyperlane protocol. When an event fires on one chain, the other chain detects and responds to it without relying on centralized off-chain relayers.

The demo uses two contracts: `HyperlaneOrigin` on Base and `HyperlaneReactive` on Reactive. Messages can flow in both directions. A `Trigger` event on Base causes the Reactive contract to detect it and forward a message back through Hyperlane. The Reactive contract can also send messages to Base directly or in response to its own `Trigger` event via a callback through the Reactive Network's log-based system.

The demo supports three messaging patterns: a direct send from Reactive to Base, a trigger-and-callback flow from Reactive to Base, and a trigger from Base to Reactive.

## Contracts

**Origin Contract**: [HyperlaneOrigin](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/hyperlane/HyperlaneOrigin.sol) is deployed on Base Mainnet. It serves as the EVM-side endpoint for cross-chain messaging. The owner can call `trigger()` to emit a `Trigger` event, which the reactive contract on the other side detects. It also implements a `handle()` function that receives incoming Hyperlane messages (restricted to the designated Hyperlane mailbox) and logs the sender metadata and payload as a `Received` event.

**Reactive Contract**:[HyperlaneReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/hyperlane/HyperlaneReactive.sol) is deployed on Reactive Mainnet. It subscribes to `Trigger` events from two sources: the origin contract on Base and itself. When either fires, the `react()` function emits a `Callback` that routes through Reactive Network back to this contract's `callback()` function, which dispatches the message to Base via Hyperlane's mailbox using on-chain fee quoting. The owner can also call `send()` to dispatch a message directly, bypassing the Reactive flow entirely.

## Deployment & Testing

### Environment Variables

Before deploying, set the following environment variables:

* `HYPERLANE_PRIVATE_KEY` — Private key for signing transactions on both Base and Reactive.

> ⚠️ **Broadcast Error**
>
> If you see `error: unexpected argument '--broadcast' found`, your Foundry version does not support the `--broadcast` flag for `forge create`. Remove it from the command and re-run.

### Step 1 — Origin Contract

Use the pre-deployed origin contract or deploy your own.

```bash
export HYPERLANE_ORIGIN_ADDR=0xF37652D7aF808287DEB26dDcb400352d8BA012Ef
```

Deploy `HyperlaneOrigin` on Base Mainnet, passing the Hyperlane mailbox address on Base (`0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D`). Save the `Deployed to` address as `HYPERLANE_ORIGIN_ADDR`.

```bash
forge create --broadcast --rpc-url https://mainnet.base.org --private-key $HYPERLANE_PRIVATE_KEY src/demos/hyperlane/HyperlaneOrigin.sol:HyperlaneOrigin --constructor-args 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D
```

### Step 2 — Reactive Contract

Use the pre-deployed Reactive contract or deploy your own.

```bash
export HYPERLANE_REACTIVE_ADDR=0xF37652D7aF808287DEB26dDcb400352d8BA012Ef
```

Deploy `HyperlaneReactive` on Reactive Mainnet with the following arguments:

- `0x3a464f746D23Ab22155710f44dB16dcA53e0775E` — Hyperlane Mailbox
- `8453` — Base chain ID
- `HYPERLANE_ORIGIN_ADDR` — Origin contract address from Step 1

Save the `Deployed to` address as `HYPERLANE_REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HYPERLANE_PRIVATE_KEY src/demos/hyperlane/HyperlaneReactive.sol:HyperlaneReactive --value 0.2ether --constructor-args 0x3a464f746D23Ab22155710f44dB16dcA53e0775E 8453 $HYPERLANE_ORIGIN_ADDR
```

### Step 3 — Test Messaging

All three messaging patterns use sample byte payloads (`0xabcdef`, `0xfedcba`, `0xdefabc`) for demonstration. Each payload will be emitted as an event on the receiving chain.

#### Direct Send (Reactive ➝ Base)

Calls `send()` on the Reactive contract, which dispatches the message to Base via Hyperlane directly. Make sure the Reactive contract holds enough REACT to cover dispatch costs. See [direct transfers](https://dev.reactive.network/economy#direct-transfers) for details on funding the contract.

```bash
cast send --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HYPERLANE_PRIVATE_KEY $HYPERLANE_REACTIVE_ADDR "send(bytes)" 0xabcdef
```

#### Trigger with Callback (Reactive ➝ Base)

Calls `trigger()` on the Reactive contract, which emits a `Trigger` event. Reactive Network detects it, routes through the RVM callback, and dispatches via Hyperlane.

```bash
cast send --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HYPERLANE_PRIVATE_KEY $HYPERLANE_REACTIVE_ADDR "trigger(bytes)" 0xfedcba
```

#### Trigger from Base (Base ➝ Reactive)

Calls `trigger()` on the origin contract on Base. The Reactive contract detects the `Trigger` event and processes it through the same callback flow.

```bash
cast send --rpc-url https://mainnet.base.org --private-key $HYPERLANE_PRIVATE_KEY $HYPERLANE_ORIGIN_ADDR "trigger(bytes)" 0xdefabc
```
