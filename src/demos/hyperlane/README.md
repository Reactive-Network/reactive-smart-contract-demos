# Hyperlane Demo

## Overview

This demo connects Base Mainnet and Reactive Mainnet using the Hyperlane protocol for two-way messaging between the networks. The goal of this setup is to show how contracts on Base and Reactive can react to each other’s activity in real time, without relying on centralized off-chain relayers. It uses two contracts:

* `HyperlaneOrigin` on Base Mainnet
* `HyperlaneReactive` on Reactive Mainnet

Messages can flow in both directions. An event on Base can trigger processing on Reactive, and Reactive can also send messages directly back to Base — either manually or in response to an event. Reactive handles incoming events using its log-based system, and forwards messages across chains through Hyperlane.

## Contracts

`HyperlaneOrigin`, deployed on Base Mainnet, serves as the EVM-side endpoint for cross-chain messaging. It emits `Trigger` events to initiate communication and defines a `handle` function for processing incoming messages. Only the contract owner can trigger events, and only the designated Hyperlane `mailbox` can deliver messages. Received payloads are logged with sender metadata for traceability.

`HyperlaneReactive`, deployed on Reactive Mainnet, listens for on-chain events and responds through Reactive’s log automation. Inheriting from `AbstractReactive` and `AbstractCallback`, it emits a `Callback` when triggered, which sends a message to `HyperlaneOrigin` using Hyperlane’s `mailbox` and on-chain fee quoting. The contract also allows manual triggering and message dispatch by the owner, supporting both automated and direct messaging from Reactive to Base.

## Environment Variables

Before deploying, set the following environment variables:

* `HYPERLANE_PRIVATE_KEY` — Private key for signing transactions on all chains.

> ⚠️ **Broadcast Error**
>
> If you see `error: unexpected argument '--broadcast' found`, your Foundry version does not support the `--broadcast` flag for `forge create`. Remove it from the command and re-run.

## Step 1 — Deploy Origin Contract

Export the deployed origin contract address:

```bash
export HYPERLANE_ORIGIN_ADDR=0xF37652D7aF808287DEB26dDcb400352d8BA012Ef
```

Deploy the origin contract on Base with the following argument:

- `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` — Hyperlane mailbox on Base Mainnet

```bash
forge create --broadcast --rpc-url https://mainnet.base.org --private-key $HYPERLANE_PRIVATE_KEY src/demos/hyperlane/HyperlaneOrigin.sol:HyperlaneOrigin --constructor-args 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D
```

## Step 2 — Deploy Reactive Contract

Export the deployed reactive contract address:

```bash
export HYPERLANE_REACTIVE_ADDR=0xF37652D7aF808287DEB26dDcb400352d8BA012Ef
```

Deploy the reactive contract with the following arguments:

- `0x3a464f746D23Ab22155710f44dB16dcA53e0775E` — Hyperlane Mailbox on Reactive Mainnet
- `8453` — Base chain ID
- `HYPERLANE_ORIGIN_ADDR` — Origin contract address from Step 1

```bash
forge create --broadcast --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HYPERLANE_PRIVATE_KEY src/demos/hyperlane/HyperlaneReactive.sol:HyperlaneReactive --value 0.2ether --constructor-args 0x3a464f746D23Ab22155710f44dB16dcA53e0775E 8453 $HYPERLANE_ORIGIN_ADDR
```

## Step 3 — Send Messages

You can now test sending messages across chains using the deployed contracts. The payloads `0xabcdef`, `0xfedcba`, and `0xdefabc` are sample byte strings for demonstration. These will be emitted as events on the receiving chain.

- `HYPERLANE_ORIGIN_ADDR` — Origin contract address from Step 1
- `HYPERLANE_REACTIVE_ADDR` — Reactive contract address from Step 2

### Direct Send (Reactive ➝ Base)

Ensure the reactive contract holds enough REACT tokens to cover message dispatch costs from Reactive to Base. Depending on current rates, each message may require 3–5 REACT. For details on topping up the contract balance, [see here](https://dev.reactive.network/economy#direct-transfers).

```bash
cast send --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HYPERLANE_PRIVATE_KEY $HYPERLANE_REACTIVE_ADDR "send(bytes)" 0xabcdef
```

### Trigger with Callback (Reactive ➝ Base)

Calls the `trigger()` function on Reactive, which runs via the dedicated RVM and sends a message via Hyperlane:

```bash
cast send --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HYPERLANE_PRIVATE_KEY $HYPERLANE_REACTIVE_ADDR "trigger(bytes)" 0xfedcba
```

### Trigger from Base (Base ➝ Reactive)

Same `trigger()` pattern, initiated from Base:

```bash
cast send --rpc-url https://mainnet.base.org --private-key $HYPERLANE_PRIVATE_KEY $HYPERLANE_ORIGIN_ADDR "trigger(bytes)" 0xdefabc
```
