# Gasless Cross-Chain Atomic Swap Demo

## Overview

The **Gasless Cross-Chain Atomic Swap Demo** implements a gasless, trustless atomic swap system that enables users to exchange tokens across different blockchain networks without requiring gas fees on the destination chain or relying on trusted intermediaries. The system leverages Reactive Smart Contracts (RSC) to automate cross-chain coordination, eliminating manual intervention and reducing gas burden for users while ensuring atomic execution.

This demo showcases how Reactive Network can orchestrate complex multi-chain operations, automatically synchronizing state between chains and executing completion logic when all conditions are met.

## Key Features

- **Gasless Execution**: Users only pay gas on their origin chain; RSC handles destination chain operations
- **Trustless Design**: No intermediaries or escrow services required
- **Atomic Swaps**: Either both sides complete successfully or the entire swap is cancelled
- **Cross-Chain State Sync**: Automatic synchronization of swap states between chains
- **Timeout Protection**: Built-in expiration mechanism to prevent stuck swaps
- **Multi-Step Coordination**: Handles complex multi-step swap lifecycle automatically



## Contracts

**Reactive Contract**: [GaslessDemoCrossChainAtomicSwapReactive](./GaslessDemoCrossChainAtomicSwapReactive.sol) orchestrates the entire cross-chain swap process by subscribing to events on both swap initiator and swap closer chains. It automatically handles state synchronization, creating swap info on the swap closer chain when a swap is initiated, updating acknowledgment status, tracking deposit confirmations, and triggering final completion on both chains. This contract eliminates the need for manual cross-chain coordination and reduces gas costs by automating all inter-chain operations.

**Swap Initiator/Closer Chain Contract**: [GaslessDemoCrossChainAtomicSwapCallback](./GaslessDemoCrossChainAtomicSwapCallback.sol) manages the swap lifecycle on each chain. It handles swap initiation, user acknowledgments, token deposits, and final token distribution. The contract includes comprehensive state management, timeout protection, and validation logic to ensure atomic execution. Users interact with this contract to initiate swaps, acknowledge participation, and deposit tokens, while the reactive contract handles cross-chain updates and completion.

## Swap Lifecycle

### 1. Initiation Phase
- **User1** calls `initiateSwap()` on the swap initiator chain (e.g., Sepolia)
- Specifies tokens, amounts, swap closer chain, and timeout
- **RSC** detects `SwapInitiated` event and creates corresponding swap info on swap closer chain

### 2. Acknowledgment Phase  
- **User2** discovers the swap opportunity on the swap closer chain (e.g., Kopli)
- Calls `acknowledgeSwap()` to participate
- **RSC** detects `SwapAcknowledged` event and updates swap initiator chain with User2's participation

### 3. Deposit Phase
- **User1** calls `depositTokens()` on swap initiator chain to commit their tokens
- **RSC** detects deposit and updates swap closer chain
- **User2** calls `depositTokens()` on swap closer chain to commit their tokens
- **RSC** detects second deposit and triggers completion

### 4. Completion Phase
- **RSC** automatically calls `completeSwap()` on both chains
- Tokens are distributed: User1 receives token2, User2 receives token1
- Swap marked as completed on both chains

## Further Considerations

The demo provides core atomic swap functionality but can be enhanced with:

- **Multi-Token Support:** Enabling swaps involving multiple token types per side
- **Partial Fill Orders:** Supporting swaps that can be partially executed
- **Fee Mechanisms:** Adding optional service fees for swap facilitation  
- **Advanced Matching:** Implementing order book or automated market maker integration
- **Enhanced Security:** Adding additional validation and emergency pause mechanisms
- **Governance Features:** Implementing parameter updates and dispute resolution

## Deployment & Testing

### Environment Variables

Before proceeding, configure these environment variables:

* `SWAP_INITIATOR_CHAIN_RPC` — RPC URL for the swap initiator chain (e.g., Ethereum Sepolia)
* `SWAP_CLOSER_CHAIN_RPC` — RPC URL for the swap closer chain (e.g., Taiko Kopli)
* `SWAP_INITIATOR_PRIVATE_KEY` — Private key for signing transactions on the swap initiator chain
* `SWAP_CLOSER_PRIVATE_KEY` — Private key for signing transactions on the swap closer chain
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet))
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network
* `SWAP_INITIATOR_CALLBACK_PROXY_ADDR` — The service address on the swap initiator chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address))
* `SWAP_CLOSER_CALLBACK_PROXY_ADDR` — The service address on the swap closer chain
* `USER1_WALLET` — Address of User1 (swap initiator)
* `USER2_WALLET` — Address of User2 (swap acknowledger)

> ℹ️ **Reactive Faucet on Sepolia**
> 
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/5, meaning you get 5 REACT for every 1 SepETH sent.
>
> **Important**: Do not send more than 10 SepETH per request, as doing so will cause you to lose the excess amount without receiving any additional REACT. The maximum that should be sent in a single transaction is 10 SepETH, which will yield 50 REACT.

> ⚠️ **Broadcast Error**
> 
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

### Step 1 — Deploy Test Tokens

Deploy ERC-20 tokens on both chains for testing. Each token mints 1000 units to the deployer:

**Swap Initiator Chain:**
```bash
forge create --broadcast --rpc-url $SWAP_INITIATOR_CHAIN_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY src/demos/gasless-cross-chain-atomic-swap/GaslessCrossChainAtomicSwapDemoToken.sol:GaslessCrossChainAtomicSwapDemoToken --constructor-args "Initiator Token" "ITK"
export INITIATOR_TOKEN=<deployed_address>
```

**Swap Closer Chain:**
```bash
forge create --broadcast --rpc-url $SWAP_CLOSER_CHAIN_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY src/demos/gasless-cross-chain-atomic-swap/GaslessCrossChainAtomicSwapDemoToken.sol:GaslessCrossChainAtomicSwapDemoToken --constructor-args "Closer Token" "CTK"
export CLOSER_TOKEN=<deployed_address>
```

### Step 2 — Deploy Callback Contracts

Deploy the swap contract on both chains:

**Swap Initiator Chain Contract:**
```bash
forge create --broadcast --rpc-url $SWAP_INITIATOR_CHAIN_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY src/demos/gasless-cross-chain-atomic-swap/GaslessDemoCrossChainAtomicSwapCallback.sol:GaslessDemoCrossChainAtomicSwapCallback --value 0.01ether --constructor-args $SWAP_INITIATOR_CALLBACK_PROXY_ADDR
export INITIATOR_CONTRACT=<deployed_address>
```

**Swap Closer Chain Contract:**
```bash
forge create --broadcast --rpc-url $SWAP_CLOSER_CHAIN_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY src/demos/gasless-cross-chain-atomic-swap/GaslessDemoCrossChainAtomicSwapCallback.sol:GaslessDemoCrossChainAtomicSwapCallback --value 0.01ether --constructor-args $SWAP_CLOSER_CALLBACK_PROXY_ADDR
export CLOSER_CONTRACT=<deployed_address>
```

### Step 3 — Deploy Reactive Contract

Deploy the reactive contract that will orchestrate the cross-chain swap:

```bash
forge create --legacy --broadcast --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/gasless-cross-chain-atomic-swap/GaslessDemoCrossChainAtomicSwapReactive.sol:GaslessDemoCrossChainAtomicSwapReactive --value 0.01ether --constructor-args 11155111 5318008 $INITIATOR_CONTRACT $CLOSER_CONTRACT
```

> **Chain IDs**: 11155111 = Ethereum Sepolia, 5318008 = Reactive Kopli. Adjust according to your target chains.

### Step 4 — Distribute Test Tokens

Transfer tokens to test users:

**Swap Initiator Chain:**
```bash
cast send $INITIATOR_TOKEN 'transfer(address,uint256)' --rpc-url $SWAP_INITIATOR_CHAIN_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY $USER1_WALLET 100000000000000000000
```

**Swap Closer Chain:**
```bash
cast send $CLOSER_TOKEN 'transfer(address,uint256)' --rpc-url $SWAP_CLOSER_CHAIN_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY $USER2_WALLET 100000000000000000000
```

### Step 5 — Approve Token Spending

Users must approve the swap contracts to spend their tokens:

**User1 approves initiator contract:**
```bash
cast send $INITIATOR_TOKEN 'approve(address,uint256)' --rpc-url $SWAP_INITIATOR_CHAIN_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY $INITIATOR_CONTRACT 50000000000000000000
```

**User2 approves closer contract:**
```bash
cast send $CLOSER_TOKEN 'approve(address,uint256)' --rpc-url $SWAP_CLOSER_CHAIN_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY $CLOSER_CONTRACT 25000000000000000000
```

### Step 6 — Execute Cross-Chain Swap

**Step 6a: User1 Initiates Swap**
```bash
cast send $INITIATOR_CONTRACT 'initiateSwap(address,uint256,address,uint256,uint256,uint256)' --rpc-url $SWAP_INITIATOR_CHAIN_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY $INITIATOR_TOKEN 50000000000000000000 $CLOSER_TOKEN 25000000000000000000 17000001 3600
```

Copy the `swapId` from the transaction logs for subsequent steps.

**Step 6b: User2 Acknowledges Swap**
```bash
cast send $CLOSER_CONTRACT 'acknowledgeSwap(bytes32)' --rpc-url $SWAP_CLOSER_CHAIN_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY $SWAP_ID
```

**Step 6c: User1 Deposits Tokens**
```bash
cast send $INITIATOR_CONTRACT 'depositTokens(bytes32)' --rpc-url $SWAP_INITIATOR_CHAIN_RPC --private-key $SWAP_INITIATOR_PRIVATE_KEY $SWAP_ID
```

**Step 6d: User2 Deposits Tokens**
```bash
cast send $CLOSER_CONTRACT 'depositTokens(bytes32)' --rpc-url $SWAP_CLOSER_CHAIN_RPC --private-key $SWAP_CLOSER_PRIVATE_KEY $SWAP_ID
```

### Step 7 — Monitor Completion

After User2 deposits, the Reactive Smart Contract will automatically:

1. Update the swap state on the swap initiator chain
2. Trigger `completeSwap()` on both chains
3. Distribute tokens to both users

Monitor the transaction logs on both chains to verify successful completion. The swap can be viewed on block explorers for both chains, with the reactive contract's activities visible on the Reactive Network.

## Verification

To verify the swap completed successfully:

**Check User1's balance of closer token:**
```bash
cast call $CLOSER_TOKEN 'balanceOf(address)' --rpc-url $SWAP_CLOSER_CHAIN_RPC $USER1_WALLET
```

**Check User2's balance of initiator token:**
```bash
cast call $INITIATOR_TOKEN 'balanceOf(address)' --rpc-url $SWAP_INITIATOR_CHAIN_RPC $USER2_WALLET
```

**Check swap status:**
```bash
cast call $INITIATOR_CONTRACT 'getSwapState(bytes32)' --rpc-url $SWAP_INITIATOR_CHAIN_RPC $SWAP_ID
cast call $CLOSER_CONTRACT 'getSwapState(bytes32)' --rpc-url $SWAP_CLOSER_CHAIN_RPC $SWAP_ID
```

Both should return `5` (SwapState.Completed).