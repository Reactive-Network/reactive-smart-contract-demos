# Gasless Cross-Chain Atomic Swap Demo

## Overview

The **Gasless Cross-Chain Atomic Swap Demo** implements a trustless atomic swap system that enables users to exchange tokens across different blockchain networks without relying on trusted intermediaries. The system leverages Reactive Smart Contracts (RSC) to automate all cross-chain coordination — users only pay gas on their own chain while the Reactive Network handles destination chain operations. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic), which provides an introduction to building reactive smart contracts that respond to real-time events.

## Contracts

**Reactive Contract**: [GaslessDemoCrossChainAtomicSwapReactive](./GaslessDemoCrossChainAtomicSwapReactive.sol) orchestrates the entire cross-chain swap by subscribing to events on both the swap initiator chain and the swap closer chain. It automatically handles state synchronization — creating swap info on the closer chain when a swap is initiated, propagating the acknowledgment back to the initiator chain, tracking deposit confirmations from both sides, and triggering final completion on both chains once all conditions are met. A single instance is deployed on the Reactive Network and requires no further manual interaction.

**Origin/Destination Chain Contract**: [GaslessDemoCrossChainAtomicSwapCallback](./GaslessDemoCrossChainAtomicSwapCallback.sol) manages the swap lifecycle on each participating chain. It handles swap initiation, user acknowledgments, token deposits, state synchronization callbacks from the RSC, and final token distribution. The contract enforces strict state-machine transitions, timeout protection, and validates chain context for every operation. The same contract binary is deployed on both chains; the RSC mirrors state between them.

## Swap Lifecycle

```
User1: initiateSwap()          ──► SwapInitiated event
                                       │
                              RSC detects, calls createSwapInfo()
                                       │
                                       ▼
User2: acknowledgeSwap()       ──► SwapAcknowledged event
                                       │
                              RSC detects, calls updateSwapInfo(Acknowledged)
                                       │
                                       ▼
User1: depositTokens()         ──► TokensDeposited(isUser1=true)
                                       │
                              RSC detects, calls updateSwapInfo(User1Deposited)
                                       │
                                       ▼
User2: depositTokens()         ──► TokensDeposited(isUser1=false)
                                       │
                              RSC detects:
                              1. updateSwapInfo(User2Deposited) on initiator chain
                              2. completeSwap() on initiator chain  → token1 → User2
                              3. completeSwap() on closer chain    → token2 → User1
```

## Further Considerations

The demo provides core atomic swap functionality but can be enhanced with:

- **Partial Fill Orders:** Supporting swaps that can be partially executed across multiple counterparties.
- **Multi-Token Support:** Enabling swaps involving baskets of tokens per side.
- **Fee Mechanisms:** Adding optional protocol fees for swap facilitation.
- **Advanced Order Matching:** Integrating order book or AMM-style matching logic.
- **Timeout Cancellation via RSC:** Automating refunds when a swap expires without completion.
- **Enhanced Security:** Additional validation, emergency pause mechanisms, and circuit breakers.

## Deployment & Testing

### Environment Variables

Before proceeding, configure these environment variables:

* `SWAP_INITIATOR_RPC` — RPC URL for the swap initiator chain (see [Chainlist](https://chainlist.org)).
* `SWAP_CLOSER_RPC` — RPC URL for the swap closer chain.
* `SWAP_INITIATOR_PRIVATE_KEY` — Private key for signing transactions on the initiator chain.
* `SWAP_CLOSER_PRIVATE_KEY` — Private key for signing transactions on the closer chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `SWAP_INITIATOR_CALLBACK_PROXY_ADDR` — Callback proxy address on the initiator chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
* `SWAP_CLOSER_CALLBACK_PROXY_ADDR` — Callback proxy address on the closer chain.
* `USER1_WALLET` — Address of User1 (swap initiator).
* `USER2_WALLET` — Address of User2 (swap acknowledger).

> ℹ️ **Reactive Faucet on Sepolia**
>
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/100, meaning you get 100 REACT for every 1 SepETH sent.
>
> **Important**: Do not send more than 5 SepETH per request, as doing so will cause you to lose the excess amount without receiving any additional REACT. The maximum that should be sent in a single transaction is 5 SepETH, which will yield 500 REACT.

> ⚠️ **Broadcast Error**
>
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

### Step 1 — Deploy Test Tokens

Deploy ERC-20 test tokens on both chains. Each token mints 100 units to the deployer:

**Swap Initiator Chain:**
```bash
forge create --broadcast --rpc-url $SWAP_INITIATOR_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY src/demos/gasless-cross-chain-atomic-swap/GaslessCrossChainAtomicSwapDemoToken.sol:GaslessCrossChainAtomicSwapDemoToken --constructor-args "Initiator Token" "ITK"
export INITIATOR_TOKEN=<deployed_address>
```

**Swap Closer Chain:**
```bash
forge create --broadcast --rpc-url $SWAP_CLOSER_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY src/demos/gasless-cross-chain-atomic-swap/GaslessCrossChainAtomicSwapDemoToken.sol:GaslessCrossChainAtomicSwapDemoToken --constructor-args "Closer Token" "CTK"
export CLOSER_TOKEN=<deployed_address>
```

### Step 2 — Deploy Callback Contracts

Deploy the same callback contract on both chains. Assign the `Deployed to` addresses accordingly:

**Swap Initiator Chain:**
```bash
forge create --broadcast --rpc-url $SWAP_INITIATOR_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY src/demos/gasless-cross-chain-atomic-swap/GaslessDemoCrossChainAtomicSwapCallback.sol:GaslessDemoCrossChainAtomicSwapCallback --value 0.01ether --constructor-args $SWAP_INITIATOR_CALLBACK_PROXY_ADDR
export INITIATOR_CONTRACT=<deployed_address>
```

**Swap Closer Chain:**
```bash
forge create --broadcast --rpc-url $SWAP_CLOSER_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY src/demos/gasless-cross-chain-atomic-swap/GaslessDemoCrossChainAtomicSwapCallback.sol:GaslessDemoCrossChainAtomicSwapCallback --value 0.01ether --constructor-args $SWAP_CLOSER_CALLBACK_PROXY_ADDR
export CLOSER_CONTRACT=<deployed_address>
```

### Step 3 — Deploy Reactive Contract

Deploy the reactive contract on the Reactive Network. Pass the chain IDs and callback contract addresses as constructor arguments. Assign the `Deployed to` address to `REACTIVE_ADDR`.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/gasless-cross-chain-atomic-swap/GaslessDemoCrossChainAtomicSwapReactive.sol:GaslessDemoCrossChainAtomicSwapReactive --value 1ether --constructor-args 11155111 5318007 $INITIATOR_CONTRACT $CLOSER_CONTRACT
```

> 📝 **Note**
>
> Chain IDs used above: `11155111` = Ethereum Sepolia (initiator), `5318007` = Reactive Lasna (closer). Adjust to match your target networks.

### Step 4 — Distribute Test Tokens

Transfer tokens to each user:

**User1 on Initiator Chain:**
```bash
cast send $INITIATOR_TOKEN 'transfer(address,uint256)' --rpc-url $SWAP_INITIATOR_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY $USER1_WALLET 50000000000000000000
```

**User2 on Closer Chain:**
```bash
cast send $CLOSER_TOKEN 'transfer(address,uint256)' --rpc-url $SWAP_CLOSER_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY $USER2_WALLET 25000000000000000000
```

### Step 5 — Approve Token Spending

Each user must approve the corresponding callback contract to transfer their tokens:

**User1 approves initiator contract:**
```bash
cast send $INITIATOR_TOKEN 'approve(address,uint256)' --rpc-url $SWAP_INITIATOR_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY $INITIATOR_CONTRACT 50000000000000000000
```

**User2 approves closer contract:**
```bash
cast send $CLOSER_TOKEN 'approve(address,uint256)' --rpc-url $SWAP_CLOSER_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY $CLOSER_CONTRACT 25000000000000000000
```

### Step 6 — Execute the Swap

**Step 6a — User1 Initiates**

User1 calls `initiateSwap()`, specifying the tokens, amounts, destination chain, and timeout (in seconds):

```bash
cast send $INITIATOR_CONTRACT 'initiateSwap(address,uint256,address,uint256,uint256,uint256)' --rpc-url $SWAP_INITIATOR_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY $INITIATOR_TOKEN 50000000000000000000 $CLOSER_TOKEN 25000000000000000000 5318007 3600
```

Copy the `swapId` from the `SwapInitiated` event logs. The RSC will automatically replicate the swap info on the closer chain.

```bash
export SWAP_ID=<swap_id_from_logs>
```

**Step 6b — User2 Acknowledges**

Once the RSC has called `createSwapInfo()` on the closer chain, User2 can acknowledge the swap:

```bash
cast send $CLOSER_CONTRACT 'acknowledgeSwap(bytes32)' --rpc-url $SWAP_CLOSER_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY $SWAP_ID
```

The RSC will propagate the acknowledgment back to the initiator chain.

**Step 6c — User1 Deposits**

After the acknowledgment has been mirrored to the initiator chain, User1 deposits their tokens:

```bash
cast send $INITIATOR_CONTRACT 'depositTokens(bytes32)' --rpc-url $SWAP_INITIATOR_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY $SWAP_ID
```

**Step 6d — User2 Deposits**

After the RSC updates the closer chain's state to `User1Deposited`, User2 deposits their tokens:

```bash
cast send $CLOSER_CONTRACT 'depositTokens(bytes32)' --rpc-url $SWAP_CLOSER_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY $SWAP_ID
```

### Step 7 — Automatic Completion

After User2's deposit the Reactive Smart Contract automatically:

1. Updates swap state to `User2Deposited` on the initiator chain.
2. Calls `completeSwap()` on the initiator chain — User2 receives `token1`.
3. Calls `completeSwap()` on the closer chain — User1 receives `token2`.

Monitor the transaction logs on both chains via block explorers to verify completion. The RSC's activity is visible on the Reactive Network explorer.

### Step 8 — Verify Completion

Check token balances to confirm the swap succeeded:

**User1 received token2 (closer chain):**
```bash
cast call $CLOSER_TOKEN 'balanceOf(address)' --rpc-url $SWAP_CLOSER_RPC $USER1_WALLET
```

**User2 received token1 (initiator chain):**
```bash
cast call $INITIATOR_TOKEN 'balanceOf(address)' --rpc-url $SWAP_INITIATOR_RPC $USER2_WALLET
```

**Check swap state on both chains** (should return `5` = Completed):
```bash
cast call $INITIATOR_CONTRACT 'getSwapState(bytes32)' --rpc-url $SWAP_INITIATOR_RPC $SWAP_ID
cast call $CLOSER_CONTRACT 'getSwapState(bytes32)' --rpc-url $SWAP_CLOSER_RPC $SWAP_ID
```

## Management Functions

### Cancel a Swap

Either participant may cancel an active or timed-out swap. Deposited tokens are automatically refunded on the appropriate chain:

```bash
cast send $INITIATOR_CONTRACT 'cancelSwap(address,bytes32,string)' --rpc-url $SWAP_INITIATOR_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY 0x0000000000000000000000000000000000000000 $SWAP_ID "User requested cancellation"
```

### Query Swap Info

```bash
cast call $INITIATOR_CONTRACT 'getSwapInfo(bytes32)' --rpc-url $SWAP_INITIATOR_RPC $SWAP_ID
```

### Query User's Swaps

```bash
cast call $INITIATOR_CONTRACT 'getUserSwaps(address)' --rpc-url $SWAP_INITIATOR_RPC $USER1_WALLET
```

### Check Expiry

```bash
cast call $INITIATOR_CONTRACT 'isSwapExpired(bytes32)' --rpc-url $SWAP_INITIATOR_RPC $SWAP_ID
```
