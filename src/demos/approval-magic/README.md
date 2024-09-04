# Magic Approval

## Overview

This demo extends reactive and subscription-based concepts to implement a sophisticated approval-based token exchange across multiple chains. The provided smart contracts facilitate token transfers and swaps by monitoring token approvals and reacting accordingly. The demo shows how an approval service, integrated with the Reactive Network, manages and executes cross-chain token exchanges, with each smart contract serving a distinct role in the overall workflow.

## Contracts and Interfaces

The demo involves five contracts and one interface, each playing a distinct role in the multi-chain token exchange workflow:

1. **Token Initialization and Distribution:** `ApprovalDemoToken` is an ERC-20 token contract that allows for the creation of a token with a specified `name` and `symbol` during deployment. It mints 100 tokens to the deploying address and includes a `request()` function to issue additional tokens (1 Ether each) to addresses that haven't previously received tokens. This contract tracks token distribution using a `recipients` mapping to prevent multiple requests from the same address.

2. **Ethereum-Based Token Exchange:** `ApprovalEthExch` is a contract that implements the `IApprovalClient` interface to manage approvals and settlements for token exchanges. It interacts with an `ApprovalService` and an ERC-20 token, providing functionalities such as owner access control, subscription management, and handling of approval callbacks to facilitate secure token transfers and settlements.

3. **Reactive Network Integration:** `ApprovalListener` implements the `IReactive` interface and interacts with both an `ISubscriptionService` and an `ApprovalService`. It can operate as either a standard contract or as a ReactVM instance, managing subscriptions and processing reactive network events to trigger actions like subscription updates or approval handling within the `ApprovalService`.

4. **Automated Token Swaps:** `ApprovalMagicSwap` is a contract that implements the `IApprovalClient` interface to facilitate token swaps using the Uniswap V2 Router. It handles subscription-based approvals through an `ApprovalService` and executes token swaps between two ERC-20 tokens (`token0` and `token1`). The contract manages swap execution by verifying token balances and allowances and performing transactions via the Uniswap Router.

5. **Subscription-Based Approval Management:** `ApprovalService` is a contract that manages subscription services and handles approval callbacks for token operations. It controls subscription status, emits relevant events (`Subscribe` and `Unsubscribe`), and processes approvals by executing operations on target contracts, settling gas fees, and updating subscription status based on transaction outcomes.

6. **Approval Handling Interface:** `IApprovalClient` is an interface that defines the essential functions for handling approvals within the workflow. It includes the `onApproval` function, which manages approval processes triggered by external actions or contracts, and the `settle` function, which handles the settlement of payments or token transfers according to the contract's requirements.

## Further Considerations

Deploying these smart contracts in a live environment involves addressing key considerations:

- **Security:** Ensuring security measures for token approvals and transfers to prevent unauthorized access.
- **Scalability:** Managing a high volume of subscribers and transactions to maintain performance.
- **Gas Optimization:** Reducing gas costs associated with approval handling to improve economic viability.
- **Interoperability:** Expanding support to a wider range of tokens and networks to improve versatility.

## Deployment & Testing

This script guides you through deploying and testing the `ApprovalMagicSwap` demo on the Sepolia Testnet. Ensure the following environment variables are configured appropriately before proceeding:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `CLIENT_WALLET`

**IMPORTANT**: The following assumes that `ApprovalService` and `ApprovalListener` are deployed using the same key. Demo token and "exchange" contract, however, can use other keys safely. You can use the recommended Sepolia RPC URL: `https://rpc2.sepolia.org`.

### Step 1 — Service Deployment

Current deployment addresses that can be reused:

```bash
export APPROVAL_SRV_ADDR=0x7e4cF81dBFd543646E5b397583B7F5ab85B3B654
export APPROVAL_RCT_ADDR=0xF37652D7aF808287DEB26dDcb400352d8BA012Ef
```

The service contracts, `ApprovalService` and `ApprovalListener`, can be deployed once, and can be used by any number of clients.

#### ApprovalService Deployment

Deploy the `ApprovalService` contract with the command below. Adjust the constructor arguments based on your requirements.

Constructor Arguments:

- Subscription Fee in Wei: Fee clients pay to subscribe.
- Gas Price Coefficient: Multiplier affecting transaction cost.
- Extra Gas for Reactive Service: Additional gas for reactive operations.

Example Values:

- Subscription Fee: 100 Wei
- Gas Price Coefficient: 1
- Extra Gas: 10

```bash
forge create src/demos/approval-magic/ApprovalService.sol:ApprovalService --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args $SUBSCRIPTION_FEE_WEI $GAS_PRICE_COEFFICIENT $REACTIVE_SERVICE_GAS
```

The `Deployed to` address should be assigned to `APPROVAL_SRV_ADDR`.

#### Reactive Deployment

Deploy the `ApprovalListener` contract with the command below. Ensure to use the same private key (`SEPOLIA_PRIVATE_KEY`). Both contracts must be deployed from the same address. This ensures that the Sepolia contract can authenticate the RVM ID for callbacks.

```bash
forge create src/demos/approval-magic/ApprovalListener.sol:ApprovalListener --rpc-url $REACTIVE_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args $APPROVAL_SRV_ADDR
```

The `Deployed to` address should be assigned to `APPROVAL_RCT_ADDR`.

### Step 2 — Demo Client Deployment

#### Token Deployment

Deploy the `ApprovalDemoToken` contract with the command given below. The constructor arguments are the name and symbol of the token you intend to deploy. As an example, use the default value "FTW" for both arguments.

```bash
forge create src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args "$TOKEN_NAME" "$TOKEN_SYMBOL"
```

The `Deployed to` address should be assigned to `TOKEN_ADDR`.

#### Client Deployment

Deploy the `ApprovalEthExch` contract with the following command:

```bash
forge create src/demos/approval-magic/ApprovalEthExch.sol:ApprovalEthExch --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args $APPROVAL_SRV_ADDR $TOKEN_ADDR
```

The `Deployed to` address should be assigned to `EXCH_ADDR`.

### Step 3 — Fund and Subscribe

#### Fund the Exchanged Contract

Transfer `1000` tokens (`SERVICE_FEE_WEI`) to the exchange contract as an example:

```bash
cast send $EXCH_ADDR --value $SERVICE_FEE_WEI --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

#### Subscribe to Approval Service

Subscribe the exchange contract to the approval service:

```bash
cast send $EXCH_ADDR "subscribe()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

**NOTE**: Dynamic subscription to approval events is not instantaneous. Typically, it takes about half a minute, which accounts for approximately twice the Sepolia's block interval plus Reactive's block interval, before the service begins processing approvals for the new subscriber.

### Step 4 — Test Approvals

Approve the token transfer for `100` tokens (`TOKENS_TO_EXCHANGE_WEI`) as an example and watch the magic happen:

```bash
cast send $TOKEN_ADDR "approve(address,uint256)" $EXCH_ADDR $TOKENS_TO_EXCHANGE_WEI --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

### Step 5 — Magic Swap Deployment

Two pre-deployed tokens:

```bash
export TOKEN1_ADDR=0x237990dfDd336f69498430e33C0e359C6590ca09
export TOKEN2_ADDR=0x623fc0b9507127a771f2DB93fBd113505304210f
```

You can request tokens (once only per token) as follows:

```bash
cast send $TOKEN1_ADDR "request()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

#### Token Deployment

Deploy two tokens and assign their addresses. As an example, use `TK1` instead of `TOKEN1_NAME` and `TOKEN1_SYMBOL`, and `TK2` instead of `TOKEN2_NAME` and `TOKEN2_SYMBOL`.

```bash
forge create src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args "TOKEN1_NAME" "TOKEN1_SYMBOL"
```

The `Deployed to` address should be assigned to `TOKEN1_ADDR`.

```bash
forge create src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args "TOKEN2_NAME" "TOKEN2_SYMBOL"
```

The `Deployed to` address should be assigned to `TOKEN2_ADDR`.

#### Create Liquidity Pool

Create a liquidity pool for the two tokens using the pair factory contract address `0x7E0987E5b3a30e3f2828572Bb659A548460a3003`, which is a constant in this context.

```bash
cast send 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 'createPair(address,address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $TOKEN1_ADDR $TOKEN2_ADDR
```

Assign the pair address from transaction logs on [Sepolia scan](https://sepolia.etherscan.io/) to `PAIR_ADDR` or export the pre-made pair for the tokens above:

```bash
export PAIR_ADDR=0xe7268aA213Ab426fAd9ca84d7fA8a380ee5B968c
```

#### Add liquidity

Transfer tokens to the pair:

```bash
cast send $TOKEN1_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $PAIR_ADDR 0.5ether
```
```bash
cast send $TOKEN2_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $PAIR_ADDR 0.5ether
```

Mint liquidity, using your EOA address:

```bash
cast send $PAIR_ADDR 'mint(address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CLIENT_WALLET
```

#### Swap Deployment

Deploy the `ApprovalMagicSwap` contract:

```bash
forge create src/demos/approval-magic/ApprovalMagicSwap.sol:ApprovalMagicSwap --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args $APPROVAL_SRV_ADDR $TOKEN1_ADDR $TOKEN2_ADDR
```

The `Deployed to` address should be assigned to `SWAP_ADDR`.

#### Fund and Subscribe Swap Contract

If needed, export the pre-deployed magic swap contract:

```bash
export SWAP_ADDR=0xaDC0233EbA6df74EA8F6c972535775F11c5a75de
```

Transfer some funds to the swap contract and subscribe to the service:


```bash
cast send $SWAP_ADDR --value 100000 --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

```bash
cast send $SWAP_ADDR "subscribe()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

### Step 6 — Test Swap

See the magic in action by approving one of the tokens to the swap contract:

```bash
cast send $TOKEN1_ADDR "approve(address,uint256)" $SWAP_ADDR 0.1ether --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```