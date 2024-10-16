# Automated Prediction Market

## Overview

This demo implements an automated prediction market system across multiple chains, leveraging reactive and subscription-based concepts. The provided smart contracts facilitate the creation, management, and resolution of prediction markets, with cross-chain interaction for automated distribution of winnings. The demo showcases how a prediction market service, integrated with the Reactive Network, can manage and execute cross-chain operations, with each smart contract serving a distinct role in the overall workflow.

## Contracts

The demo involves two main contracts:

1. **Sepolia Testnet Contract:** `AutomatedPredictionMarket` manages the core prediction market functionality, including market creation, share purchases, resolution proposals, and voting.

2. **Reactive Testnet Contract:** `AutomatedPredictionReactive` listens for prediction resolution events and triggers the distribution of winnings via callbacks to the origin contract.

## Further Considerations

Deploying these smart contracts in a live environment involves addressing key considerations:

- **Security:** Ensuring robust security measures for market creation, betting, and resolution processes.
- **Scalability:** Managing a high volume of predictions, bets, and cross-chain interactions.
- **Gas Optimization:** Reducing gas costs associated with market operations and cross-chain callbacks.
- **Governance:** Implementing a fair and efficient voting system for market resolutions.

## Deployment & Testing

This guide walks you through deploying and testing the `AutomatedPredictionMarket` demo on the Sepolia Testnet and the Reactive Testnet. Ensure the following environment variables are configured appropriately before proceeding:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SYSTEM_CONTRACT_ADDR`
* `O_ORIGIN_ADDR`

### Sepolia Testnet Steps

1. Deploy the `AutomatedPredictionMarket` contract:

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/automated-prediction-market/AutomatedPredictionMarket.sol:AutomatedPredictionMarket --constructor-args 0x0000000000000000000000000000000000000000
```

#### Callback Payment

To ensure a successful callback, the callback contract must have an ETH balance. You can find more details [here](https://dev.reactive.network/system-contract#callback-payments). To fund the callback contract, run the following command:

```bash
cast send $CALLBACK_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether
```

Alternatively, you can deposit the funds into the callback proxy smart contract using this command:

```bash
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CALLBACK_PROXY_ADDR "depositTo(address)" $CALLBACK_ADDR --value 0.1ether
```


2. Initialize the contract with required parameters initialize:

```bash
cast send $PREDICTION_MARKET_ADDR "initialize(string,string,uint256,uint256,uint256,uint256,address[],uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

3. Create a prediction:

```bash
cast send $PREDICTION_MARKET_ADDR "createPrediction(string,uint256,uint256[],uint256,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

4. Users purchase shares:

```bash
cast send $PREDICTION_MARKET_ADDR "purchaseShares(uint256,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

5. Propose resolution:

```bash
cast send $PREDICTION_MARKET_ADDR "proposeResolution(uint256,bool)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

6. (MultiSig Holders)Vote on resolution:

```bash
cast send $PREDICTION_MARKET_ADDR "voteOnResolution(uint256,uint256,bool)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

### Reactive Deployment

1. Deploy the `AutomatedPredictionReactive` contract:

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/automated-prediction-market/AutomatedPredictionReactive.sol:AutomatedPredictionReactive --constructor-args $SYSTEM_CONTRACT_ADDR $O_ORIGIN_ADDR
```

2. The contract automatically subscribes to the `PredictionResolved` event on deployment.

3. When a prediction is resolved on Sepolia, the Reactive contract's `react` function is triggered automatically.

4. The `react` function emits a `Callback` event to call `distributeWinnings` on Sepolia.

## Cross-chain Interaction

The cross-chain functionality is emulated by:

1. The `AutomatedPredictionMarket` contract on Sepolia emitting the `PredictionResolved` event.
2. The `AutomatedPredictionReactive` contract on Reactive listening for this event.
3. The Reactive contract then triggering a callback to Sepolia to distribute winnings.

This setup ensures that the two contracts communicate only through the Reactive Smart Contract, simulating a cross-chain interaction.