# Approval Magic Demo

## Overview

The **Approval Magic Demo** extends reactive and subscription-based concepts to implement an approval-based token exchange across multiple chains. The provided smart contracts facilitate token transfers and swaps by monitoring token approvals and reacting accordingly. The demo shows how an approval service integrated with the Reactive Network manages and executes cross-chain token exchanges, with each smart contract serving a distinct role in the overall workflow.

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

Deploy the contracts to Ethereum Sepolia and Reactive Kopli by following these steps. Ensure the following environment variables are configured:

* `SEPOLIA_RPC` — RPC URL for Ethereum Sepolia, (see [Chainlist](https://chainlist.org/chain/11155111))
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — RPC URL for Reactive Kopli (see [Reactive Docs](https://dev.reactive.network/kopli-testnet#reactive-kopli-information))
* `CLIENT_WALLET` — Deployer's EOA wallet address

**Faucet**: To receive REACT tokens, send SepETH to the Reactive faucet at `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. An equivalent amount of REACT will be sent to your address.

**Note**: Use the same private key for deploying `ApprovalService` and `ApprovalListener`. `ApprovalDemoToken` and `ApprovalEthExch` may use different keys if needed.

## Magic Exchange

### Step 1 — Approval Service

Use the pre-deployed `ApprovalService` contract or deploy your own.

```bash
export APPROVAL_SRV_ADDR=0x204a2CD5A5c45289B0CD520Bc409888885a32B8d
```

To deploy `ApprovalService`, run the following command with the specified constructor arguments:

- Subscription Fee (in Wei): `100`
- Gas Price Coefficient: `1`
- Extra Gas for Reactive Service: `10`

```bash
forge create src/demos/approval-magic/ApprovalService.sol:ApprovalService --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args 100 1 10
```

The `Deployed to` address from the response should be assigned to `APPROVAL_SRV_ADDR`.

### Step 2 — Approval Listener

Use the pre-deployed `ApprovalListener` contract or deploy your own.

```bash
export APPROVAL_RCT_ADDR=0x2afaFD298b23b62760711756088F75B7409f5967
```

Deploy the `ApprovalListener` contract using the same private key from Step 1. This ensures the `ApprovalService` contract can authenticate the RVM ID for callbacks.

```bash
forge create src/demos/approval-magic/ApprovalListener.sol:ApprovalListener --rpc-url $REACTIVE_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether --constructor-args $APPROVAL_SRV_ADDR
```

The `Deployed to` address should be assigned to `APPROVAL_RCT_ADDR`.

### Step 3 — Client Contract

#### Token Deployment

Deploy the `ApprovalDemoToken` contract with the specified name and symbol (e.g., `"FTW"`): 

```bash
forge create src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args "FTW" "FTW"
```

The `Deployed to` address should be assigned to `TOKEN_ADDR`.

#### Client Contract Deployment

Deploy the `ApprovalEthExch` contract:

```bash
forge create src/demos/approval-magic/ApprovalEthExch.sol:ApprovalEthExch --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args $APPROVAL_SRV_ADDR $TOKEN_ADDR
```

The `Deployed to` address should be assigned to `EXCH_ADDR`.

### Step 4 — Fund and Subscribe

#### Fund the Exchange Contract

Transfer `1000` tokens (Service Fee in Wei) to the exchange contract:

```bash
cast send $EXCH_ADDR --value 1000 --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

#### Subscribe to Approval Service

Subscribe the exchange contract to `ApprovalService`:

```bash
cast send $EXCH_ADDR "subscribe()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

**NOTE**: The subscription process takes approximately 30 seconds, accounting for both Sepolia's and Reactive's block intervals, before the service starts processing approvals.

### Step 5 — Test Approvals

Approve the transfer of `100` tokens (in Wei) to the exchange contract:

```bash
cast send $TOKEN_ADDR "approve(address,uint256)" $EXCH_ADDR 100 --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

## Magic Swap

### Step 1 — Token Deployment

Use the pre-deployed tokens or deploy your own.

```bash
export TOKEN1_ADDR=0x193cA0ED388b871f4Cb188B60C016fD0826fba37
export TOKEN2_ADDR=0x4f4D678939407Ca230f972F928E2B32641dD330D
```

You can request each token once:

```bash
cast send 0x193cA0ED388b871f4Cb188B60C016fD0826fba37 "request()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

```bash
cast send 0x4f4D678939407Ca230f972F928E2B32641dD330D "request()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

Deploy two tokens, each with constructor arguments `"TOKEN_NAME"` and `"TOKEN_SYMBOL"`:

```bash
forge create src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args "TK1" "TK1"
```

The `Deployed to` address should be assigned to `TOKEN1_ADDR`.

```bash
forge create src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args "TK2" "TK2"
```

The `Deployed to` address should be assigned to `TOKEN2_ADDR`.

### Step 2 — Create Liquidity Pool

If you use pre-deployed tokens from the previous step, export the address of their Uniswap pair:

```bash
export UNISWAP_PAIR_ADDR=0xd2Bf9571B410fCb598Bde8fa6A0C40f0A80F56ef
```

To create a new pair, run the following command with the Uniswap V2 Factory contract `0x7E0987E5b3a30e3f2828572Bb659A548460a3003` and the token addresses deployed in the previous step.

```bash
cast send 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 'createPair(address,address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $TOKEN1_ADDR $TOKEN2_ADDR
```

Assign the Uniswap pair address from transaction logs as shown on [Sepolia scan](https://sepolia.etherscan.io/tx/0x4a373bc6ebe815105abf44e6b26e9cdcd561fb9e796196849ae874c7083692a4/advanced#eventlog) to `UNISWAP_PAIR_ADDR`.

### Step 3 — Add liquidity

Transfer liquidity into the created pool:

```bash
cast send $TOKEN1_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $UNISWAP_PAIR_ADDR 0.5ether
```
```bash
cast send $TOKEN2_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $UNISWAP_PAIR_ADDR 0.5ether
```

Mint the liquidity pool tokens to your wallet:

```bash
cast send $UNISWAP_PAIR_ADDR 'mint(address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CLIENT_WALLET
```

### Step 4 — Swap Deployment

Use the pre-deployed swap contract or deploy your own.

```bash
export SWAP_ADDR=0xDee41516471b52A662d3A2af70639CEF0A77fFA0
```

To deploy the `ApprovalMagicSwap` contract:

```bash
forge create src/demos/approval-magic/ApprovalMagicSwap.sol:ApprovalMagicSwap --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args $APPROVAL_SRV_ADDR $TOKEN1_ADDR $TOKEN2_ADDR
```

The `Deployed to` address should be assigned to `SWAP_ADDR`.

### Step 5 — Fund and Subscribe

Transfer some funds to the swap contract and subscribe to the service:

```bash
cast send $SWAP_ADDR --value 100000 --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

```bash
cast send $SWAP_ADDR "subscribe()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

### Step 6 — Test Swap

See the magic in action by approving one of the tokens (e.g., `TOKEN1_ADDR`) for the swap contract:

```bash
cast send $TOKEN1_ADDR "approve(address,uint256)" $SWAP_ADDR 0.1ether --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```