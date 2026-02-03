# Leverage Loop Demo

## Overview

The **Leverage Loop Demo** implements a reactive smart contract that orchestrates an automated leverage looping strategy.

In decentralized finance (DeFi), "looping" is a strategy where a user supplies collateral to a lending protocol, borrows against it, swaps the borrowed asset for more collateral, supplies it again, and repeats the process to maximize their position. This is typically a manual and gas-intensive process involving multiple transactions and constant monitoring of Loan-To-Value (LTV) ratios.

This demo automates the entire process using the Reactive Network. A user simply deposits funds into a smart account. The **LoopingRSC** detects this deposit and automatically executes a series of "loops" — borrowing, swapping, and supplying — until a target LTV is reached, all without further user intervention.

This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts.

## Contracts

**Leverage Account**: [LeverageAccount](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/leverage-loop/LeverageAccount.sol) operates as the user's personal vault on the destination chain (e.g., Ethereum Sepolia). It holds the user's collateral and debt positions. It listens for callbacks from the Reactive Network to execute individual leverage steps (borrow -> swap -> supply).

**Reactive Contract**: [LoopingRSC](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/leverage-loop/LoopingRSC.sol) monitors the `LeverageAccount` for `Deposited` and `LoopStepExecuted` events.
- On `Deposited`: If the LTV is below the target (75%), it initiates the first leverage loop.
- On `LoopStepExecuted`: It checks if the target LTV is reached or if the maximum iteration count is met. If not, it triggers the next loop.

**Mock Infrastructure**:
- **[MockToken](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/leverage-loop/mock/MockToken.sol)**: Simulates ERC-20 tokens (WETH, USDT).
- **[MockRouter](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/leverage-loop/mock/MockRouter.sol)**: Simulates a DEX for swapping borrowed assets into collateral.
- **[MockLendingPool](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/leverage-loop/mock/MockLendingPool.sol)**: Simulates a lending protocol (like Aave) allowing supply, borrow, repay, and withdraw actions.

## Deployment & Testing

### Environment Variables

Before proceeding, configure these environment variables:

*   `DESTINATION_RPC` — RPC URL for the destination chain (e.g., Sepolia).
*   `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
*   `REACTIVE_RPC` — RPC URL for the Reactive Network.
*   `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
*   `DESTINATION_CALLBACK_PROXY_ADDR` — The callback proxy address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
*   `SYSTEM_CONTRACT_ADDR` — The service address on the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet#overview)).
*   `CLIENT_WALLET` — Your wallet address.

> ℹ️ **Reactive Faucet on Sepolia**
>
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/100, meaning you get 100 REACT for every 1 SepETH sent.
>
> **Important**: Do not send more than 5 SepETH per request, as doing so will cause you to lose the excess amount without receiving any additional REACT. The maximum that should be sent in a single transaction is 5 SepETH, which will yield 500 REACT.

> ⚠️ **Broadcast Error**
>
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

### Step 1 — Deploy Mock Infrastructure

First, deploy the mock tokens, router, and lending pool on the destination chain (Sepolia).

**1. Deploy WETH and USDT:**

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/leverage-loop/mock/MockToken.sol:MockToken --constructor-args "Wrapped Ether" "WETH"
```
*Export the deployed address as `WETH_ADDR`.*

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/leverage-loop/mock/MockToken.sol:MockToken --constructor-args "Tether USD" "USDT"
```
*Export the deployed address as `USDT_ADDR`.*

**2. Deploy Mock Router:**

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/leverage-loop/mock/MockRouter.sol:MockRouter
```
*Export the deployed address as `ROUTER_ADDR`.*

**3. Configure Prices (Oracle):**
Set WETH price to $3000 and USDT to $1.

```bash
cast send $ROUTER_ADDR "setPrice(address,uint256)" $WETH_ADDR 3000000000000000000000 --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
cast send $ROUTER_ADDR "setPrice(address,uint256)" $USDT_ADDR 1000000000000000000 --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

**4. Deploy Mock Lending Pool:**

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/leverage-loop/mock/MockLendingPool.sol:MockLendingPool --constructor-args $ROUTER_ADDR
```
*Export the deployed address as `POOL_ADDR`.*

**5. Add Assets to Pool:**

```bash
cast send $POOL_ADDR "addAsset(address)" $WETH_ADDR --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
cast send $POOL_ADDR "addAsset(address)" $USDT_ADDR --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

### Step 2 — Deploy Leverage Account

Deploy the user's smart account on the destination chain. Initially, we set the `_rscCaller` to `address(0)` or our wallet, and will update it after deploying the Reactive contract.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/leverage-loop/LeverageAccount.sol:LeverageAccount --constructor-args $POOL_ADDR $ROUTER_ADDR $DESTINATION_CALLBACK_PROXY_ADDR $CLIENT_WALLET
```
*Export the deployed address as `LEV_ACCOUNT_ADDR`.*

### Step 3 — Deploy Reactive Contract

Deploy the control logic on the Reactive Network.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/leverage-loop/LoopingRSC.sol:LoopingRSC --constructor-args $SYSTEM_CONTRACT_ADDR $LEV_ACCOUNT_ADDR $WETH_ADDR $USDT_ADDR
```
*Export the deployed address as `RSC_ADDR`.*

> **Note**: The `LoopingRSC` is configured to listen to events on Sepolia Chain ID `11155111`. Ensure you are deploying the destination contracts on Sepolia or update the Chain ID in `LoopingRSC.sol` regarding your environment.

### Step 4 — Authorize RSC and Fund Account

**1. Authorize the RSC:**
Allow the deployed RSC to call `executeLeverageStep` on your Leverage Account.

```bash
cast send $LEV_ACCOUNT_ADDR "setRSCCaller(address)" $RSC_ADDR --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

**2. Mint & Approve Test Tokens:**
Mint some WETH to your wallet to use as initial collateral.

```bash
cast send $WETH_ADDR "mint(address,uint256)" $CLIENT_WALLET 10000000000000000000 --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
cast send $WETH_ADDR "approve(address,uint256)" $LEV_ACCOUNT_ADDR 10000000000000000000 --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

**3. Provide Liquidity to Mock Router:**
The router needs USDT to swap against your borrowed WETH (or vice versa depending on strategy, here we borrow USDT and swap to WETH).
Mint USDT and send to Router.

```bash
cast send $USDT_ADDR "mint(address,uint256)" $ROUTER_ADDR 100000000000000000000000 --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```
*Also mint WETH to Router for the swap:*
```bash
cast send $WETH_ADDR "mint(address,uint256)" $ROUTER_ADDR 100000000000000000000 --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

### Step 5 — Execute the Loop

Trigger the process by depositing WETH into your Leverage Account.

```bash
cast send $LEV_ACCOUNT_ADDR "deposit(address,uint256)" $WETH_ADDR 1000000000000000000 --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

This action will:
1.  Emit a `Deposited` event on Sepolia.
2.  `LoopingRSC` detects the event and emits a `Callback`.
3.  `LeverageAccount` receives the callback, borrows USDT, swaps it for WETH, and supplies the WETH.
4.  A `LoopStepExecuted` event is emitted.
5.  `LoopingRSC` detects this and repeats the loop until the target LTV is reached (max 3 iterations in this demo).

You can monitor the transaction events on Sepolia Etherscan and the Reactive Explorer.