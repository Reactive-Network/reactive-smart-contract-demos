# Automated Prediction Market

## Overview

The **Automated Prediction Market** system implements a decentralised prediction market on Ethereum Sepolia with automated, cross-chain winnings distribution powered by the Reactive Network. Users create predictions, purchase shares, and propose resolutions through multisig voting. When a prediction is resolved, the Reactive contract detects the on-chain event and automatically triggers a callback to distribute winnings to all winning participants — no manual intervention required. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts that respond to real-time events.

## Contracts

**Origin/Destination Chain Contract**: [AutomatedPredictionMarket](./AutomatedPredictionMarket.sol) manages the full lifecycle of prediction markets on Ethereum Sepolia: market creation, share purchases with referral rewards, resolution proposals, and multisig-gated voting. When sufficient votes are cast, the contract finalises the outcome on-chain and emits a `PredictionResolved` event. Winnings are then distributed in batches via a callback from the Reactive Network by the `distributeWinnings` function, which is protected by `authorizedSenderOnly`.

**Reactive Contract**: [AutomatedPredictionReactive](./AutomatedPredictionReactive.sol) subscribes to `PredictionResolved` events emitted by the callback contract on Sepolia. When the event fires, the `react` function decodes the prediction ID and emits a `Callback` event targeting `distributeWinnings` on Sepolia, closing the cross-chain loop automatically.

## Further Considerations

The demo showcases essential prediction market functionality but can be improved with:

- **Security:** Strengthening market creation, betting, and resolution flows against manipulation.
- **Scalability:** Handling high volumes of predictions, bets, and cross-chain callbacks efficiently.
- **Gas Optimisation:** Reducing costs for market operations and batch winnings distribution.
- **Advanced Order Types:** Supporting more complex resolution mechanisms such as multi-outcome markets or oracle-based resolution.
- **Multiple Resolvers:** Expanding multisig to support larger, more decentralised governance structures.

## Deployment & Testing

### Environment Variables

Before proceeding, configure the following environment variables:

* `DESTINATION_RPC` — RPC URL for the destination chain (Ethereum Sepolia), (see [Chainlist](https://chainlist.org)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `DESTINATION_CALLBACK_PROXY_ADDR` — The service address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
* `OWNER_WALLET` — Your EOA wallet address that will own and manage the contracts.
* `MULTISIG_ADDRESS1`, `MULTISIG_ADDRESS2` — Addresses of the multisig wallet holders.
* `MULTISIG1_PRIVATE_KEY`, `MULTISIG2_PRIVATE_KEY` — Private keys of the multisig holders.
* `VOTER1_PRIVATE_KEY`, `VOTER2_PRIVATE_KEY`, `VOTER3_PRIVATE_KEY` — Private keys for share purchasers.
* `PROPOSER_PRIVATE_KEY` — Private key of the resolution proposer.

> ℹ️ **Reactive Faucet on Sepolia**
>
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/100, meaning you get 100 REACT for every 1 SepETH sent.
>
> **Important**: Do not send more than 5 SepETH per request, as doing so will cause you to lose the excess amount without receiving any additional REACT. The maximum that should be sent in a single transaction is 5 SepETH, which will yield 500 REACT.

> ⚠️ **Broadcast Error**
>
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

### Step 1 — Deploy the Callback Contract

Deploy `AutomatedPredictionMarket` on Ethereum Sepolia, passing the Sepolia callback proxy address. Assign the `Deployed to` address to `CALLBACK_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/automated-prediction-market/AutomatedPredictionMarketCallback.sol:AutomatedPredictionMarketCallback --value 1ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR
```

### Step 2 — Deploy the Reactive Contract

Deploy `AutomatedPredictionReactive` on the Reactive Network, specifying your wallet as owner and the callback address from Step 1. Assign the `Deployed to` address to `REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/automated-prediction-market/AutomatedPredictionReactive.sol:AutomatedPredictionReactive --value 1ether --constructor-args $CALLBACK_ADDR
```

### Step 3 — Initialise the Contract

Configure the prediction market parameters. The example values below set a minimum bet of 0.001 ETH, a 5% fee, a 20% referral reward, two multisig holders, and a required signature threshold of 1.

```bash
cast send $CALLBACK_ADDR "initialize(uint256,uint256,uint256,address[],uint256)" \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  1000000000000000 5 20 [$MULTISIG_ADDRESS1,$MULTISIG_ADDRESS2] 1
```

### Step 4 — Create a Prediction

Create a prediction market with a 15-minute total duration, 10 minutes of betting, and 5 minutes for resolution proposals.

```bash
cast send $CALLBACK_ADDR "createPrediction(string,uint256,uint256[],uint256,uint256)" \
  --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY \
  "Will ETH price touch \$2,600 in the next 15 mins?" 900 [1,2] 600 300
```

This creates prediction ID `0`.

### Step 5 — Purchase Shares

Users purchase shares for their chosen outcome. Option `0` maps to the first option (Yes), option `1` to the second (No).

```bash
cast send $CALLBACK_ADDR "purchaseShares(uint256,uint256)" \
  --rpc-url $DESTINATION_RPC --private-key $VOTER1_PRIVATE_KEY \
  0 0 --value 2000000000000000
```

```bash
cast send $CALLBACK_ADDR "purchaseShares(uint256,uint256)" \
  --rpc-url $DESTINATION_RPC --private-key $VOTER2_PRIVATE_KEY \
  0 0 --value 1000000000000000
```

```bash
cast send $CALLBACK_ADDR "purchaseShares(uint256,uint256)" \
  --rpc-url $DESTINATION_RPC --private-key $VOTER3_PRIVATE_KEY \
  0 0 --value 3000000000000000
```

### Step 6 — Propose a Resolution

Once the prediction period has ended, any participant can stake ETH to propose an outcome. Pass `true` to propose option index 1 (Yes) wins, `false` for option index 0 (No).

```bash
cast send $CALLBACK_ADDR "proposeResolution(uint256,bool)" \
  --rpc-url $DESTINATION_RPC --private-key $PROPOSER_PRIVATE_KEY \
  0 true --value 1000000000000000
```

### Step 7 — Vote on Resolution

Multisig holders vote on the proposed resolution. Once the required number of approvals is reached, the prediction is finalised and `PredictionResolved` is emitted.

```bash
cast send $CALLBACK_ADDR "voteOnResolution(uint256,uint256,bool)" \
  --rpc-url $DESTINATION_RPC --private-key $MULTISIG1_PRIVATE_KEY \
  0 0 true
```

When the `PredictionResolved` event is emitted, the Reactive contract's `react` function fires automatically and emits a `Callback` to call `distributeWinnings` on Sepolia.

### Step 8 — Verify Distribution

Monitor the callback contract on [SEPOLIA ETHERSCAN](https://sepolia.etherscan.io/) for `RewardsClaimed` and `WinningsDistributed` events to confirm that payouts have been executed.

You can also query how far distribution has progressed:

```bash
cast call $CALLBACK_ADDR "predictions(uint256)" --rpc-url $DESTINATION_RPC 0
```

## Architecture

The system consists of two contracts working in tandem:

1. **Callback Contract (on Ethereum Sepolia):** Holds all market logic — creation, betting, voting, resolution, and batch distribution. The `distributeWinnings` function is the entry point for the Reactive callback.

2. **Reactive Contract (on Reactive Network):** Monitors `PredictionResolved` events and autonomously triggers `distributeWinnings` via a cross-chain callback.

**Event Flow:**

```
User votes on resolution
        ↓
requiredSignatures reached → _finalizeResolution()
        ↓
PredictionResolved emitted on Sepolia
        ↓
Reactive contract react() fires on Reactive Network
        ↓
Callback emitted → distributeWinnings() called on Sepolia
        ↓
RewardsClaimed events emitted for each winning participant
```

## Managing the Market

**Set a referral (before purchasing shares):**

```bash
cast send $CALLBACK_ADDR "setReferral(address)" \
  --rpc-url $DESTINATION_RPC --private-key $VOTER1_PRIVATE_KEY \
  $REFERRER_ADDRESS
```

**Check if an address is a multisig holder:**

```bash
cast call $CALLBACK_ADDR "isMultiSigWallet(address)" \
  --rpc-url $DESTINATION_RPC $MULTISIG_ADDRESS1
```
