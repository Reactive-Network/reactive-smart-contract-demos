# Leverage Loop Demo

## Overview

The **Leverage Loop Demo** implements a reactive smart contract that orchestrates an automated leverage looping strategy.

In decentralized finance (DeFi), "looping" is a strategy where a user supplies collateral to a lending protocol, borrows against it, swaps the borrowed asset for more collateral, supplies it again, and repeats the process to maximize their position. This is typically a manual and gas-intensive process involving multiple transactions and constant monitoring of Health Factors.

This demo automates the entire process using the Reactive Network. A user simply deposits funds into a smart account. The **LoopingRSC** detects this deposit and automatically executes a series of "loops" — borrowing, swapping, and supplying — until a target Health Factor is reached, all without further user intervention.

This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts.

## Contracts

**Leverage Account**: [LeverageAccount](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/leverage-loop/LeverageAccount.sol) operates as the user's personal vault on the destination chain (e.g., Ethereum Sepolia). It holds the user's collateral and debt positions. It listens for callbacks from the Reactive Network to execute individual leverage steps (borrow -> swap -> supply), featuring dynamic slippage protection using real-time oracles.

**Reactive Contract**: [LoopingRSC](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/leverage-loop/LoopingRSC.sol) monitors the `LeverageAccount` for `Deposited` and `LoopStepExecuted` events.
- On `Deposited`: If the Health Factor is above the target (1.5), it initiates the first leverage loop.
- On `LoopStepExecuted`: It checks if the Health Factor has dropped below the safety threshold (1.2), reached the target (1.5), or if the maximum iteration count (5) is met. If not, it triggers the next loop.

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

### Step 1 — Configuration

Export the following addresses for the Aave V3 Market and Uniswap V3 on Sepolia:

```bash
# Aave V3 Pool (Sepolia)
export POOL_ADDR=0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951

# Uniswap V3 SwapRouter (Sepolia)
export ROUTER_ADDR=0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E

# WETH (Aave V3 Supported)
export WETH_ADDR=0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c

# USDC (Aave V3 Supported, 6 decimals)
export BORROW_ASSET_ADDR=0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8
export BORROW_ASSET_DECIMALS=6
```

### Step 2 — Deploy Leverage Account

Deploy the user's smart account on the destination chain.

```bash
forge create --broadcast --value 0.001ether --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/leverage-loop/LeverageAccount.sol:LeverageAccount --constructor-args $POOL_ADDR $ROUTER_ADDR $DESTINATION_CALLBACK_PROXY_ADDR $CLIENT_WALLET
```
*Export the deployed address as `LEV_ACCOUNT_ADDR`.*

### Step 3 — Deploy Reactive Contract

Deploy the control logic on the Reactive Network.

```bash
forge create --broadcast --value 1ether --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/leverage-loop/LoopingRSC.sol:LoopingRSC --constructor-args $SYSTEM_CONTRACT_ADDR $LEV_ACCOUNT_ADDR $WETH_ADDR $BORROW_ASSET_ADDR $BORROW_ASSET_DECIMALS
```
*Export the deployed address as `RSC_ADDR`.*

> **Note**: The `LoopingRSC` is configured to listen to events on Sepolia Chain ID `11155111`. Ensure you are deploying the destination contracts on Sepolia or update the Chain ID in `LoopingRSC.sol` regarding your environment.

### Step 4 — Authorize RSC and Fund Account

**1. Authorize the RSC:**
Allow the deployed RSC to call `executeLeverageStep` on your Leverage Account.

```bash
cast send $LEV_ACCOUNT_ADDR "setRSCCaller(address)" $RSC_ADDR --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

**2. Set Chainlink Oracles:**
Configure price feeds so the contract can calculate slippage protection.

```bash
# WETH/USD oracle on Sepolia
cast send $LEV_ACCOUNT_ADDR "setOracle(address,address)" $WETH_ADDR $WETH_USD_ORACLE --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY

# USDC/USD oracle on Sepolia
cast send $LEV_ACCOUNT_ADDR "setOracle(address,address)" $BORROW_ASSET_ADDR $USDC_USD_ORACLE --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```


**3. Fund your wallet with WETH:**

Ensure you have WETH in your wallet. You can wrap SepETH into WETH:

```bash
cast send $WETH_ADDR "deposit()" --value 0.05ether --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

### Step 5 — Execute the Loop

Approve WETH spending, then deposit into your Leverage Account.

```bash
# Approve the LeverageAccount to pull your WETH
DEPOSIT_AMOUNT=10000000000000000  # 0.01 WETH

cast send $WETH_ADDR "approve(address,uint256)" $LEV_ACCOUNT_ADDR $DEPOSIT_AMOUNT --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY

# Deposit WETH to start the leverage loop
cast send $LEV_ACCOUNT_ADDR "deposit(address,uint256)" $WETH_ADDR $DEPOSIT_AMOUNT --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY
```

> **Minimum Deposit Amount**: The `LoopingRSC` enforces a minimum borrow threshold (`MIN_BORROW_USD`). The borrow amount is calculated as a percentage of your deposit's USD value:
>
> ```
> borrowAmountUSD = depositValueUSD * INITIAL_LEVERAGE_FACTOR / 10000
> ```
>
> With the default `INITIAL_LEVERAGE_FACTOR` of 40% and `MIN_BORROW_USD` of `$0.1` (testnet), your deposit must be worth at least **$0.25 USD** for the loop to start. If the computed borrow falls below this threshold, the RSC emits a `LoopStopped("Borrow amount below minimum")` event and no callback is sent.
>
> For **mainnet**, you should increase `MIN_BORROW_USD` to a practical value (e.g., `10e18` for $10) to avoid dust-sized borrows that waste gas.
>
> **Example calculation** (at ETH ~ $2,600):
> | Deposit | USD Value | Borrow (40%) | Passes Min? |
> |---------|-----------|-------------|-------------|
> | 0.001 WETH | ~$2.60 | ~$1.04 | Yes (testnet) |
> | 0.01 WETH | ~$26 | ~$10.40 | Yes |
> | 0.05 WETH | ~$130 | ~$52 | Yes |

This action will:
1.  Emit a `Deposited` event on Sepolia.
2.  `LoopingRSC` on the Reactive Network detects the event and calculates a safe borrow amount.
3.  If the borrow amount passes the minimum threshold, it emits a `Callback`.
4.  `LeverageAccount` receives the callback, borrows USDC, swaps it for WETH on Uniswap V3, and supplies the WETH back to Aave.
5.  A `LoopStepExecuted` event is emitted.
6.  `LoopingRSC` detects this and repeats the loop until the target Health Factor (1.5) is reached or max iterations (5) are hit.

You can monitor the transaction events on Sepolia Etherscan and the Reactive Explorer.

### Troubleshooting

**`FailedInnerCall()` (selector `0x1425ea42`) on deposit:**
This OpenZeppelin error means an internal call failed. Common causes:
- You haven't approved the `LeverageAccount` to spend your WETH (run the `approve` step first).
- Your wallet doesn't hold enough WETH. Verify with:
  ```bash
  cast call $WETH_ADDR "balanceOf(address)(uint256)" $CLIENT_WALLET --rpc-url $DESTINATION_RPC
  ```
- You're using the wrong WETH address. Aave V3 on Sepolia uses `0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c`, **not** the canonical Sepolia WETH (`0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9`).

**`LoopStopped("Borrow amount below minimum")` on Reactive Network:**
Your deposit is too small. Increase the deposit amount or lower `MIN_BORROW_USD` in `LoopingRSC.sol` for testing.

**RSC detects the event but no callback arrives on Sepolia:**
The RSC contract needs native REACT tokens to pay for callbacks. Fund it:
```bash
cast send $RSC_ADDR --value 0.1ether --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

**Decoding revert data:**
Use `cast` to identify unknown error selectors:
```bash
cast 4byte 0x1425ea42  # Returns: FailedInnerCall()
```