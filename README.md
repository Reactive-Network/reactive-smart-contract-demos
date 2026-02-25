# Reactive Smart Contract Demos

## Overview

This repository contains a collection of demo projects for [Reactive Network](https://reactive.network) — a blockchain that lets smart contracts automatically react to events happening on other blockchains.

Each demo in the `src/demos` directory walks through a specific use case with its own README, contracts, and deployment instructions. Examples range from simple cross-chain messaging to automated DeFi operations like stop orders on Uniswap. All contracts are written in Solidity and the project uses the [Foundry](https://www.getfoundry.sh/) development framework.

## Demos

### Basic Demo

The starting point for understanding how Reactive Network works. This demo shows the core pattern behind Reactive Contracts: a contract on an origin chain emits an event, a Reactive contract on Reactive Network detects that event, and a callback is sent to a contract on a destination chain. It uses three contracts — `BasicDemoL1Contract.sol` (origin), `BasicDemoL1Callback.sol` (destination), and `BasicDemoReactiveContract.sol` (Reactive) — to walk through this full lifecycle. If you're new to Reactive Network, start here.

### Cron Demo

This demo demonstrates time-based automation using Reactive Network's built-in cron mechanism. Unlike traditional blockchains, where smart contracts can only execute in response to user transactions, Reactive Network's system contract emits cron events at fixed block intervals, essentially giving smart contracts a clock to work with. The contract in this demo subscribes to these periodic cron events and performs actions on a schedule, without any external trigger. This pattern is useful for tasks like periodic data updates, scheduled reward distributions, or regular health checks on DeFi positions.

### Hyperlane Demo

This demo connects Base Mainnet and Reactive Mainnet using the Hyperlane protocol for two-way cross-chain messaging without relying on centralized off-chain relayers or Reactive's default callback proxy. It uses two contracts: `HyperlaneOrigin.sol`, deployed on Base, which emits trigger events and receives incoming messages via a trusted Hyperlane mailbox; and `HyperlaneReactive.sol`, deployed on Reactive, which listens for those events and can send messages back through Hyperlane. Messages flow in both directions, either automatically in response to events or triggered manually by the contract owner. This shows how Reactive Network can integrate with external messaging protocols for flexible cross-chain communication.

### Uniswap V2 Stop Order Demo

This demo implements automated stop orders on Uniswap V2 liquidity pools. A Reactive contract monitors exchange rate changes on a Uniswap V2 pair by subscribing to its on-chain sync events. When the rate crosses a user-defined threshold, the Reactive contract triggers a callback to a destination chain contract (`UniswapDemoStopOrderCallback.sol`) that executes the swap. This is a practical DeFi use case: stop-loss and take-profit orders that work automatically, without requiring the user to watch the market or run a bot.

### Approval Magic Demo

This demo shows how Reactive Contracts can automate token approvals and trigger cross-chain exchanges without manual intervention. It uses a subscription-based model where users register with an `ApprovalService.sol` contract, and an `ApprovalListener.sol` Reactive contract watches for ERC-20 approval events on-chain. When an approval is detected, the system can automatically initiate a token swap or exchange on behalf of the user. This demonstrates how event-centric automation can simplify multi-step DeFi workflows that would normally require users to submit several transactions by hand.

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

The `src/demos` directory contains all available demos each with their own `README.md` files.

### Environment Variable Configuration

The following environment variables are used in the instructions for running the demos, and should be configured beforehand.

#### `ORIGIN/DESTINATION_RPC`

RPC URL for the origin/destination chain (see [Chainlist](https://chainlist.org)).

#### `ORIGIN/DESTINATION_PRIVATE_KEY`

Private key for signing transactions on the origin/destination chain.

#### `REACTIVE_RPC`

RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).

#### `REACTIVE_PRIVATE_KEY`

Private key for signing transactions on the Reactive Network.

#### `SYSTEM_CONTRACT_ADDR`

The service address for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet#overview)).

#### `CALLBACK_PROXY_ADDR`

The address that verifies callback authenticity (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
