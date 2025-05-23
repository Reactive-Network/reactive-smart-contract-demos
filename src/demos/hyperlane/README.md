# Hyperlane Demo

## Environment Variables

Before proceeding further, configure these environment variables:

* `HYPERLANE_PRIVATE_KEY` — Private key for signing transactions on all chains.

> ⚠️ **Broadcast Error**  
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

## Step 1 — Deploy Origin Contract

Export the deployed origin contract address:

```bash
export HYPERLANE_ORIGIN_ADDR=0xF37652D7aF808287DEB26dDcb400352d8BA012Ef
```

Deploy the origin contract on Base with the following argument:

- `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` — The Hyperlane mailbox address used for sending messages from Base

```bash
forge create --broadcast --rpc-url https://mainnet.base.org --private-key $HYPERLANE_PRIVATE_KEY src/demos/hyperlane/HyperlaneOrigin.sol:HyperlaneOrigin --constructor-args 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D
```

## Step 2 — Deploy Reactive Contract

Export the deployed reactive contract address:

```bash
export HYPERLANE_REACTIVE_ADDR=0xF37652D7aF808287DEB26dDcb400352d8BA012Ef
```

Deploy the reactive contract with the following arguments:

- `0x3a464f746D23Ab22155710f44dB16dcA53e0775E` — Mailbox on Reactive
- `8453` — Base chain ID
- `HYPERLANE_ORIGIN_ADDR` — Origin contract address from Step 1

```bash
forge create --legacy --broadcast --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HYPERLANE_PRIVATE_KEY src/demos/hyperlane/HyperlaneReactive.sol:HyperlaneReactive --value 0.2ether --constructor-args 0x3a464f746D23Ab22155710f44dB16dcA53e0775E 8453 $HYPERLANE_ORIGIN_ADDR
```

## Step 3 — Send Messages

You can now test sending messages across chains using the deployed contracts. The payloads `0xabcdef`, `0xfedcba`, and `0xdefabc` are sample byte strings for demonstration. These will be emitted as events on the receiving chain.

- `HYPERLANE_ORIGIN_ADDR` — Origin contract address from Step 1
- `HYPERLANE_REACTIVE_ADDR` — Reactive contract address from Step 2

### Direct Send (Reactive ➝ Base)

Sends a message directly from Reactive to Base:

```bash
cast send --legacy --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HYPERLANE_PRIVATE_KEY $HYPERLANE_REACTIVE_ADDR "send(bytes)" 0xabcdef
```

### Trigger with Callback (Reactive ➝ Base)

Calls the `trigger()` function on Reactive, which runs via the dedicated RVM and sends a message via Hyperlane:

```bash
cast send --legacy --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HYPERLANE_PRIVATE_KEY $HYPERLANE_REACTIVE_ADDR "trigger(bytes)" 0xfedcba
```

### Trigger from Base (Base ➝ Reactive)

Same `trigger()` pattern, initiated from Base:

```bash
cast send --rpc-url https://mainnet.base.org --private-key $HYPERLANE_PRIVATE_KEY $HYPERLANE_ORIGIN_ADDR "trigger(bytes)" 0xdefabc
```
