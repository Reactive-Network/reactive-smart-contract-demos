# Approval Magic Demo

## Overview

The **Approval Magic Demo** extends reactive and subscription-based concepts to implement an approval-based token exchange across multiple chains. The provided smart contracts facilitate token transfers and swaps by monitoring token approvals and reacting accordingly. The demo shows how an approval service integrated with the Reactive Network manages and executes cross-chain token exchanges, with each smart contract serving a distinct role in the overall workflow.

## Magic Exchange Flow

![Exchange](./img/exchange.png)

1. Validator calls `callback()` on `CallbackProxy`.
2. `CallbackProxy` calls `onApproval()` on `ApprovalService`.
3. `ApprovalService` calls `onApproval()` on `ApprovalEthExch`, which:
    - Transfers tokens from the EOA signing the transaction.
    - Sends ETH to the EOA signing the transaction, equivalent to the token amount.
4. `ApprovalService` then calls `settle()` on `ApprovalEthExch`, which:
    - Sends ETH to `ApprovalService` for gas.

## Magic Swap Flow

![Swap](./img/swap.png)

1. Validator calls `callback()` on `CallbackProxy`.
2. `CallbackProxy` calls `onApproval()` on `ApprovalService`.
3. `ApprovalService` calls `onApproval()` on `ApprovalMagicSwap`, which:
   - Transfers approved tokens from the EOA signing the transaction.
   - Approves Uniswap router.
   - Swaps the tokens via Uniswap.
   - Sends the output tokens back to the EOA signing the transaction.
4. `ApprovalService` then calls `settle()` on `ApprovalMagicSwap`, which:
   - Sends ETH to `ApprovalService` for gas.

## Contracts

**Subscription-Based Approval Service**: The [ApprovalService](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/approval-magic/ApprovalService.sol) contract is responsible for subscription-based approvals. Users (or contracts) can subscribe by paying a fee, enabling them to receive and process approval callbacks that originate from token approvals. This service tracks subscribers, covers the gas cost of triggered callbacks, and emits `Subscribe`/`Unsubscribe` events. If the subscription conditions aren’t met or a contract fails to pay for its gas usage, the subscriber is automatically unsubscribed.

**Reactive Contract**: The [ApprovalListener](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/approval-magic/ApprovalListener.sol) contract elaborates on how the Reactive Network can integrate with the `ApprovalService`. It listens for specific log events — such as `Subscribe`, `Unsubscribe`, and ERC-20 approval signatures — and reacts accordingly. When these events occur, `ApprovalListener` triggers callbacks to manage subscriptions or handle token approvals.

**Token Initialization and Distribution**: The [ApprovalDemoToken](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/approval-magic/ApprovalDemoToken.sol) is an ERC-20 token used for testing. At deployment, it mints 100 tokens for the deployer. Additionally, anyone can call `request()` once to receive 1 token (costing 1 Ether).

**Token Exchange**: The [ApprovalEthExch](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/approval-magic/ApprovalEthExch.sol) contract shows how a subscription-based approval flow can facilitate token-for-ETH exchanges. It relies on `ApprovalService` to handle approval callbacks, ensuring tokens can be transferred without requiring extra user interaction. Owners can manage subscriptions, withdraw funds, and perform this exchange as a building block for more complex trading or DeFi protocols.

**Automated Token Swaps**: The [ApprovalMagicSwap](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/approval-magic/ApprovalMagicSwap.sol) contract extends the subscription-based approach by incorporating Uniswap V2 token swaps. When a token approval triggers a callback, this contract automatically swaps the approved tokens for another ERC-20 token via Uniswap — again, without requiring the user to take any extra steps.

## Further Considerations

Deploying these smart contracts in a live environment involves addressing key considerations:

- **Security:** Ensuring security measures for token approvals and transfers to prevent unauthorized access.
- **Scalability:** Managing a high volume of subscribers and transactions to maintain performance.
- **Gas Optimization:** Reducing gas costs associated with approval handling to improve economic viability.
- **Interoperability:** Expanding support to a wider range of tokens and networks to improve versatility.

## Deployment & Testing

### Environment Variables

Before proceeding further, configure these environment variables:

* `DESTINATION_RPC` — RPC URL for the destination chain, (see [Chainlist](https://chainlist.org)).
* `DESTINATION_PRIVATE_KEY` — Private key for signing transactions on the destination chain.
* `REACTIVE_RPC` — RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).
* `REACTIVE_PRIVATE_KEY` — Private key for signing transactions on the Reactive Network.
* `CLIENT_WALLET` — Deployer's EOA wallet address
* `DESTINATION_CALLBACK_PROXY_ADDR` — The service address on the destination chain (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).

> ℹ️ **Reactive Faucet on Sepolia**
> 
> To receive testnet REACT, send SepETH to the Reactive faucet contract on Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. The factor is 1/100, meaning you get 100 REACT for every 1 SepETH sent.
> 
> **Important**: Do not send more than 5 SepETH per request, as doing so will cause you to lose the excess amount without receiving any additional REACT. The maximum that should be sent in a single transaction is 5 SepETH, which will yield 500 REACT.

> ⚠️ **Broadcast Error**
> 
> If you see the following message: `error: unexpected argument '--broadcast' found`, it means your Foundry version (or local setup) does not support the `--broadcast` flag for `forge create`. Simply remove `--broadcast` from your command and re-run it.

> 📝 **Note**
> 
> Use the same private key for deploying `ApprovalService` and `ApprovalListener`. `ApprovalDemoToken` and `ApprovalEthExch` may use different keys if needed.

## Magic Exchange

### Step 1 — Approval Service

Use the pre-deployed `ApprovalService` contract or deploy your own.

```bash
export APPROVAL_SRV_ADDR=0xfc2236a0d3421473676c4c422046fbc4f1afdffe
```

To deploy `ApprovalService`, run the following command with the specified constructor arguments:

- Subscription Fee: `123wei`
- Gas Price Coefficient: `2`
- Extra Gas for Reactive Service: `35000`

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/approval-magic/ApprovalService.sol:ApprovalService --value 0.03ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR 123wei 2 35000
```

Blockchain Explorer: [ApprovalService Deployment](https://sepolia.etherscan.io/tx/0x7b71693930662ed56450d943885afa3682f74ae143671d89a58e2a32c02ddfc3) | [Contract Address](https://sepolia.etherscan.io/address/0x18CC39cE700B13899D5A3a97FcC607B6B93c0947)

The `Deployed to` address from the response should be assigned to `APPROVAL_SRV_ADDR`.

### Step 2 — Approval Listener

Use the pre-deployed `ApprovalListener` contract or deploy your own.

```bash
export APPROVAL_RCT_ADDR=0xc3e185561D2a8b04F0Fcd104A562f460D6cC503c
```

Deploy the `ApprovalListener` contract using the same private key from Step 1. This ensures the `ApprovalService` contract can authenticate the RVM ID for callbacks.

```bash
forge create --broadcast --rpc-url $REACTIVE_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/approval-magic/ApprovalListener.sol:ApprovalListener --value 0.1ether --constructor-args $DESTINATION_CHAIN_ID $APPROVAL_SRV_ADDR
```

Blockchain Explorer: [ApprovalListener Deployment](https://lasna.reactscan.net/tx/0x205fea0cbb6b2beecfb3af5b685b42a35d62a6ca7593df2a04a4d6a829af318c) | [Contract Address](https://lasna.reactscan.net/address/0x49abe186a9b24f73e34ccae3d179299440c352ac/contract/0x442A2343D56165eb30AAf78Ac159C33bf190F51C)

The `Deployed to` address should be assigned to `APPROVAL_RCT_ADDR`.

### Step 3 — Token Contract Deployment

Deploy the `ApprovalDemoToken` contract with the specified name and symbol (e.g., `"FTW"`):

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --constructor-args "FTW" "FTW"
```

Blockchain Explorer: [ApprovalDemoToken Deployment](https://sepolia.etherscan.io/tx/0x01a0750eda235c48bb25708a5db585d39774e6c0037280e4e7fcf54872f698ea) | [Contract Address](https://sepolia.etherscan.io/address/0xd4181095958471f4D39c1e07F375c768532db0ac)

The `Deployed to` address should be assigned to `TOKEN_ADDR`.

### Step 4 — Exchange Contract Deployment

Deploy the `ApprovalEthExch` contract:

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/approval-magic/ApprovalEthExch.sol:ApprovalEthExch --value 0.01ether --constructor-args $APPROVAL_SRV_ADDR $TOKEN_ADDR
```

Blockchain Explorer: [ApprovalEthExch Deployment](https://sepolia.etherscan.io/tx/0xe169772bda99b82c2ded8e418dba9a6a93f30f6bf84cb3528b5d404e73a0fd23) | [Contract Address](https://sepolia.etherscan.io/address/0x5aA00326B4859e972B1Ee4CBB74fc73497c381b6)

The `Deployed to` address should be assigned to `EXCH_ADDR`.

### Step 5 — Subscribe and Approve

Subscribe the exchange contract to `ApprovalService`:

```bash
cast send --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $EXCH_ADDR "subscribe()"
```

Blockchain Explorer: [Subscribe Transaction](https://sepolia.etherscan.io/tx/0xf2c323ac365dd7e29173e5dbf5efb678c3be6448c3b503d1a75e80f9a086bb65)

> 📝 **Note**
> The subscription process takes approximately 30 seconds, accounting for both destination and Reactive's block intervals, before the service starts processing approvals.

Approve the transfer of `1000` tokens (in Wei) to the exchange contract:

```bash
cast send --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $TOKEN_ADDR "approve(address,uint256)" $EXCH_ADDR 1000
```

Blockchain Explorer: [Approve Transaction](https://sepolia.etherscan.io/tx/0x2811bf415be4c71d42cebff53fd4fe665621604606427c3a4e059193c2e533c1)

## Magic Swap

### Step 1 — Token Deployment

Use the pre-deployed tokens or deploy your own.

```bash
export TOKEN1_ADDR=0xBa1aD75feE4d0bC41A946466443790da4b14825c
export TOKEN2_ADDR=0x764396E26e0D9d7A544e8b4E45efA1048364F294
```

You can request each token once:

```bash
cast send --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0xBa1aD75feE4d0bC41A946466443790da4b14825c "request()" 
```

```bash
cast send --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0x764396E26e0D9d7A544e8b4E45efA1048364F294 "request()"
```

Or deploy two tokens, each with constructor arguments `"TOKEN_NAME"` and `"TOKEN_SYMBOL"`:

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --constructor-args "TK1" "TK1"
```

Blockchain Explorer: [TK1 Token Deployment](https://sepolia.etherscan.io/tx/0x26be1b98f3092771e2a279ee88e8c5a2438762d0e6add4f4f990e4eac9a6c8ff) | [Contract Address](https://sepolia.etherscan.io/address/0x81a1eAA99113e33b55c9E66348Ec2ef18a14B9A5)

The `Deployed to` address should be assigned to `TOKEN1_ADDR`.

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --constructor-args "TK2" "TK2"
```

Blockchain Explorer: [TK2 Token Deployment](https://sepolia.etherscan.io/tx/0xc2b389199a4d6816da127c16cbb42750acacd7ecdb476cb25aa6d961b39fdd44) | [Contract Address](https://sepolia.etherscan.io/address/0xA740AB77DFb1C630E6eFD78F330Ce990a884c8d4)

The `Deployed to` address should be assigned to `TOKEN2_ADDR`.

### Step 2 — Create Liquidity Pool

If you use pre-deployed tokens from the previous step, export the address of their Uniswap pair:

```bash
export UNISWAP_PAIR_ADDR=0x0498833E5632BC525d57D84F4d0f2f063adf678D
```

To create a new pair, run the following command with the Uniswap V2 Factory contract `0x7E0987E5b3a30e3f2828572Bb659A548460a3003` and the token addresses deployed in the previous step.

```bash
cast send --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 'createPair(address,address)' $TOKEN1_ADDR $TOKEN2_ADDR
```

Blockchain Explorer: [Create Pair Transaction](https://sepolia.etherscan.io/tx/0xfa77e8ed23e746e1787502b76fd3f4487c7d64e971ebd5a2224863f5f31c17f1)

Assign the Uniswap pair address from transaction logs as shown on [Sepolia scan](https://sepolia.etherscan.io/tx/0xfa77e8ed23e746e1787502b76fd3f4487c7d64e971ebd5a2224863f5f31c17f1#eventlog) to `UNISWAP_PAIR_ADDR`.

### Step 3 — Add Funds and Mint

Transfer liquidity into the created pool:

```bash
cast send --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $TOKEN1_ADDR 'transfer(address,uint256)' $UNISWAP_PAIR_ADDR 0.5ether
```

Blockchain Explorer: [Transfer TK1 to Pair](https://sepolia.etherscan.io/tx/0x104d7b4cafffc69db5bdb9bf8acf13002e2ebeaa49090c252bcb01fe29abc5f6)

```bash
cast send --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $TOKEN2_ADDR 'transfer(address,uint256)' $UNISWAP_PAIR_ADDR 0.5ether
```

Blockchain Explorer: [Transfer TK2 to Pair](https://sepolia.etherscan.io/tx/0x5d3b9d6853b12baaa4f9d3ce5d549c6d44645b5edc9e24d984811b59c49cb570)

Mint the liquidity pool tokens to your wallet:

```bash
cast send --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $UNISWAP_PAIR_ADDR 'mint(address)' $CLIENT_WALLET
```

Blockchain Explorer: [Mint LP Tokens](https://sepolia.etherscan.io/tx/0x4abbe0bec7c7e07ab63f5127909a57375a23a30fdf80cd0c521a25b6ce04d397)

### Step 4 — Swap Contract Deployment

Use the pre-deployed swap contract or deploy your own.

```bash
export SWAP_ADDR=0x08295A6650b7388B6941dD7Fe5c03E9EC895DBA9
```

To deploy the `ApprovalMagicSwap` contract:

```bash
forge create --broadcast --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY src/demos/approval-magic/ApprovalMagicSwap.sol:ApprovalMagicSwap --value 0.01ether --constructor-args $APPROVAL_SRV_ADDR $TOKEN1_ADDR $TOKEN2_ADDR
```

Blockchain Explorer: [ApprovalMagicSwap Deployment](https://sepolia.etherscan.io/tx/0xcb3dc2dac0d33ab41d72e3b727c0eba8f36cd417c60deb14f262a9245d31d180) | [Contract Address](https://sepolia.etherscan.io/address/0xB6549E6C5E84309DEf65320925bE2Eb65A83F1dE)

The `Deployed to` address should be assigned to `SWAP_ADDR`.

### Step 5 — Subscribe and Approve

Subscribe the swap contract to `ApprovalService`:

```bash
cast send --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $SWAP_ADDR "subscribe()"
```

Blockchain Explorer: [Subscribe Transaction](https://sepolia.etherscan.io/tx/0xef56eb68328dfc567fca912bd33f716e95d1ca9a9308ec41f258dcb1181baa9c)

See the magic in action by approving one of the tokens (e.g., `TOKEN1_ADDR`) for the swap contract:

```bash
cast send --rpc-url $DESTINATION_RPC --private-key $DESTINATION_PRIVATE_KEY $TOKEN1_ADDR "approve(address,uint256)" $SWAP_ADDR 0.1ether
```

Blockchain Explorer: [Approve Transaction](https://sepolia.etherscan.io/tx/0xc38f234737db749800c12c888ba12a94b8384346056bc02a4705c073f144d646)