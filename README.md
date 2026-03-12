# Reactive Contract Demos

## Overview

This repository contains a collection of demo projects for Reactive Network — a blockchain designed for event-driven, cross-chain smart contract automation.

Each demo in the [src/demos](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos) directory focuses on a specific automation pattern, with its own README, contracts, and deployment steps. The examples cover:

* Core cross-chain event → callback flows
* Time-based execution using CRON events
* Cross-chain messaging integrations
* DeFi automation such as stop-loss / take-profit orders on Uniswap V2
* Automated liquidation protection on Aave

All contracts are written in Solidity, and the repository uses the Foundry development framework for building, testing, and deployment. Together, these demos show how Reactive Contracts can replace manual monitoring and off-chain bots with deterministic, event-centric on-chain logic.

## Demos

### Basic Demo

[Basic Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic) is the starting point for understanding how Reactive Network works. This demo shows the core pattern behind Reactive Contracts: a contract on an origin chain emits an event, a Reactive contract on Reactive Network detects that event, and a callback is sent to a contract on a destination chain. It uses three contracts — `BasicDemoL1Contract.sol` (origin), `BasicDemoL1Callback.sol` (destination), and `BasicDemoReactiveContract.sol` (Reactive) — to walk through this full lifecycle. If you're new to Reactive Network, start here.

### Cron Demo

[Cron Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/cron) explains how to implement time-based automation using Reactive Network's built-in cron mechanism. Unlike traditional blockchains, where smart contracts can only execute in response to user transactions, Reactive Network's system contract emits cron events at fixed block intervals, essentially giving smart contracts a clock to work with. The contract in this demo subscribes to these periodic cron events and performs actions on a schedule, without any external trigger. This pattern is useful for tasks like periodic data updates, scheduled reward distributions, or regular health checks on DeFi positions.

### Hyperlane Demo

[Hyperlane Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/hyperlane) connects Base Mainnet and Reactive Mainnet using the [Hyperlane](https://www.hyperlane.xyz/) protocol for two-way cross-chain messaging without relying on centralized off-chain relayers or Reactive's default callback proxy. It uses two contracts: `HyperlaneOrigin.sol`, deployed on Base, which emits trigger events and receives incoming messages via a trusted Hyperlane mailbox; and `HyperlaneReactive.sol`, deployed on Reactive, which listens for those events and can send messages back through Hyperlane. Messages flow in both directions, either automatically in response to events or triggered manually by the contract owner. This shows how Reactive Network can integrate with external messaging protocols for flexible cross-chain communication.

### Uniswap V2 Stop Order Demo

[Uniswap V2 Stop Order Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/uniswap-v2-stop-order) implements automated stop orders on Uniswap V2 liquidity pools. A Reactive contract monitors exchange rate changes on a Uniswap V2 pair by subscribing to its on-chain sync events. When the rate crosses a user-defined threshold, the Reactive contract triggers a callback to a destination chain contract (`UniswapDemoStopOrderCallback.sol`) that executes the swap. This is a practical DeFi use case: stop-loss and take-profit orders that work automatically, without requiring the user to watch the market or run a bot.

### Uniswap V2 Stop-Loss & Take-Profit Orders Demo

[Uniswap V2 Stop-Loss & Take-Profit Orders Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/uniswap-v2-stop-take-profit-order) shows how to automate both stop-loss and take-profit strategies using Reactive Contracts. A personal Reactive Contract subscribes to `Sync` events from a Uniswap V2 pair and monitors reserve changes. When a user-defined price threshold is crossed, the Reactive Contract emits a callback that triggers the swap on the destination chain. Each user deploys their own contracts, ensuring isolated order management and full control over execution. This demo demonstrates event-driven trade automation without relying on off-chain bots.

### Aave Liquidation Protection Demo

[Aave Liquidation Protection Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/aave-liquidation-protection) shows how to automate position protection on Aave using Reactive Contracts. A personal Reactive Contract subscribes to periodic CRON events and triggers health checks for a user’s lending position. When the user’s health factor drops below a defined threshold, the system executes protection measures on the destination chain — depositing additional collateral, repaying debt, or both. The callback contract calculates the required amount and performs the interaction with Aave. This demo demonstrates time-based, event-driven liquidation protection without manual monitoring or external bots, with each user deploying their own isolated protection setup.

### Approval Magic Demo

[Approval Magic Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/approval-magic) shows how Reactive Contracts can automate token approvals and trigger cross-chain exchanges without manual intervention. It uses a subscription-based model where users register with an `ApprovalService.sol` contract, and an `ApprovalListener.sol` Reactive contract watches for ERC-20 approval events on-chain. When an approval is detected, the system can automatically initiate a token swap or exchange on behalf of the user. This demonstrates how event-driven automation can simplify multi-step DeFi workflows that would normally require users to submit several transactions by hand.

## Deployment Instructions

### Environment Setup

To set up `foundry` environment, run:

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

### Additional Documentation & Demos

Each demo in `src/demos` has its own `README.md` with detailed deployment steps.

### Environment Variable Configuration

The following environment variables are used in the instructions for running the demos, and should be configured beforehand.

#### `ORIGIN/DESTINATION_RPC`

RPC URL for the origin/destination chain (see [Chainlist](https://chainlist.org)).

#### `ORIGIN/DESTINATION_PRIVATE_KEY`

Private key for signing transactions on the origin/destination chain.

#### `REACTIVE_RPC`

RPC URL for Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).

#### `REACTIVE_PRIVATE_KEY`

Private key for signing transactions on Reactive Network.

#### `SYSTEM_CONTRACT_ADDR`

The service address for Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet#overview)).

#### `CALLBACK_PROXY_ADDR`

The address that verifies callback authenticity (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
