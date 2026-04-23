# Reactive Contract Demos

## Overview

This repository contains a collection of demo projects for Reactive Network, a blockchain designed for event-driven, cross-chain smart contract automation. Each demo in the [src/demos](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos) directory focuses on a specific automation pattern, with its own README, contracts, and deployment steps. The examples cover:

* Core cross-chain event → callback flows
* Time-based execution using CRON events
* Cross-chain messaging integrations
* DeFi automation such as stop-loss / take-profit orders on Uniswap V2
* Automated liquidation protection on Aave
* Leveraged looping on Aave
* Automated prediction market payouts
* Gasless cross-chain atomic swaps.

All contracts are written in Solidity, and the repository uses the Foundry development framework for building, testing, and deployment. Together, these demos show how Reactive Contracts can replace manual monitoring and off-chain bots with deterministic, event-centric on-chain logic.

## Demos

### Basic Demo

[Basic Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic) is the starting point for understanding how Reactive Network works. A contract on an origin chain emits an event, a Reactive contract detects it, and a callback is sent to a contract on a destination chain. It uses three contracts to walk through this full lifecycle: `BasicDemoL1Contract.sol` (origin), `BasicDemoL1Callback.sol` (destination), and `BasicDemoReactiveContract.sol` (Reactive). If you're new to Reactive Network, start here.

### Cron Demo

[Cron Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/cron) shows how to implement time-based automation using Reactive Network's built-in cron mechanism. The system contract emits cron events at fixed block intervals, giving Reactive contracts a clock to work with. The contract in this demo subscribes to these periodic events and performs actions on a schedule, without any external trigger. This pattern is useful for periodic data updates, scheduled reward distributions, or regular health checks on DeFi positions.

### Uniswap V2 Stop Order Demo

[Uniswap V2 Stop Order Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/uniswap-v2-stop-order) implements a decentralized stop-loss order for a Uniswap V2 trading pair. A Reactive contract monitors the pair's `Sync` events and tracks reserve changes. When the exchange rate drops below a user-defined threshold, it triggers a callback to a destination chain contract that executes the swap through the Uniswap V2 Router and returns the proceeds to the user.

### Uniswap V2 Stop-Loss & Take-Profit Orders Demo

[Uniswap V2 Stop-Loss & Take-Profit Orders Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/uniswap-v2-stop-take-profit-order) extends the stop order pattern with support for both stop-loss and take-profit strategies, full order lifecycle management, and per-user contract isolation. A personal Reactive contract subscribes to `Sync` events, dynamically manages pair subscriptions as orders are created and completed, and monitors reserve changes against each order's threshold.

### Approval Magic Demo

[Approval Magic Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/approval-magic) shows how a single `approve()` transaction can automatically trigger a cross-chain exchange or swap. An `ApprovalListener` Reactive contract monitors ERC-20 approval events and subscription changes from an `ApprovalService` registry. When an approval targets a subscribed contract, the listener triggers a callback that transfers the approved tokens and completes the trade: either a direct token-for-ETH exchange or a token-for-token swap via Uniswap V2.

### Hyperlane Demo

[Hyperlane Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/hyperlane) connects Base Mainnet and Reactive Mainnet using the [Hyperlane](https://www.hyperlane.xyz/) protocol for two-way cross-chain messaging without relying on centralized off-chain relayers. `HyperlaneOrigin.sol` on Base emits trigger events and receives incoming messages via a Hyperlane mailbox; `HyperlaneReactive.sol` on Reactive listens for those events and can send messages back through Hyperlane.

### Aave Liquidation Protection Demo

[Aave Liquidation Protection Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/aave-liquidation-protection) automates position protection on Aave using Reactive contracts. A personal Reactive contract subscribes to periodic CRON events and triggers health checks for a user's lending position. When the health factor drops below a defined threshold, the system executes protection measures on the destination chain: depositing additional collateral, repaying debt, or both.

### Leverage Loop Demo

[Leverage Loop Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/leverage-loop) automates leveraged looping on Aave V3 using Reactive contracts. The user deposits collateral into a personal smart account, and a Reactive contract detects the deposit and runs the loop automatically until the target health factor is reached or the maximum iteration count is hit.

### Automated Prediction Market Demo

[Automated Prediction Market Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/automated-prediction-market) implements a prediction market with automated payouts. Users create a question, participants buy shares in different outcomes, and a multisig resolves the result. Once the `PredictionResolved` event is emitted, a Reactive contract detects it and triggers batch distribution of winnings to all participants.

### Gasless Cross-Chain Atomic Swap Demo

[Gasless Cross-Chain Atomic Swap Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/gasless-cross-chain-atomic-swap) enables trustless token exchanges between two blockchains without bridges or custodians. Two users initiate and acknowledge a swap on their respective chains, deposit tokens, and a Reactive contract handles the entire process: syncing state, confirming deposits, and triggering completion on both chains automatically. The swap is atomic: it either completes for both parties or doesn't happen at all. Users only pay gas on their own chain.

## Deployment Instructions

### Environment Setup

To set up the Foundry environment, run:

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

Install dependencies:

```bash
forge install
```

### Development & Testing

To compile artifacts:

```bash
forge compile
```

To run the test suite:

```bash
forge test -vv
```

To inspect the call tree:

```bash
forge test -vvvv
```

### Additional Documentation

Each demo in `src/demos` has its own `README.md` with detailed contract descriptions and deployment steps.

### Environment Variable Reference

The following environment variables are used across the demos and should be configured before deployment.

`ORIGIN_RPC` / `DESTINATION_RPC` — RPC URL for the origin or destination chain (see [Chainlist](https://chainlist.org)).

`ORIGIN_PRIVATE_KEY` / `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the origin or destination chain.

`REACTIVE_RPC` — RPC URL for Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).

`REACTIVE_PRIVATE_KEY` — Private key for signing transactions on Reactive Network.

`SYSTEM_CONTRACT_ADDR` — The service address for Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet#overview)).

`CALLBACK_PROXY_ADDR` — The address that verifies callback authenticity (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).