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

**IMPORTANT**: The following assumes that `ApprovalService` and `ApprovalListener` are deployed using the same private key. Demo token and "exchange" contract, however, can use other keys safely. The recommended Sepolia RPC URL is `https://rpc2.sepolia.org`.

### Step 1 — Service Deployment

Current deployment addresses that can be reused:

```bash
export APPROVAL_SRV_ADDR=0x6B40d71F3888D70fEBca5da8bFe453527dD3A94b
export APPROVAL_RCT_ADDR=0xB64c6fFAf5B605Fc48b868c514C9dac421245f6d
```

The `ApprovalService` and `ApprovalListener` contracts can be deployed once and used by any number of clients.

#### ApprovalService Deployment

To deploy the `ApprovalService` contract, run the command given below. The constructor requires these arguments:

- Subscription Fee (in Wei): `100`
- Gas Price Coefficient: `1`
- Extra Gas for Reactive Service: `10`

```bash
forge create src/demos/approval-magic/ApprovalService.sol:ApprovalService --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args 100 1 10
```

The `Deployed to` address from the response should be assigned to `APPROVAL_SRV_ADDR`.

**NOTE**: To ensure a successful callback, the callback contract (`APPROVAL_SRV_ADDR` in our case) must have an ETH balance. You can find more details [here](https://dev.reactive.network/system-contract#callback-payments). To fund the contract, run the following command:

```bash
cast send $APPROVAL_SRV_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether
```

Alternatively, you can deposit funds into the [Sepolia callback proxy contract](https://dev.reactive.network/origins-and-destinations) using this command:

```bash
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CALLBACK_PROXY_ADDR "depositTo(address)" $APPROVAL_SRV_ADDR --value 0.1ether
```

#### Reactive Deployment

Deploy the `ApprovalListener` contract with the command shown below. Make sure to use the same private key (`SEPOLIA_PRIVATE_KEY`). Both contracts must be deployed from the same address as this ensures that the Sepolia contract can authenticate the RVM ID for callbacks.

```bash
forge create src/demos/approval-magic/ApprovalListener.sol:ApprovalListener --rpc-url $REACTIVE_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether --constructor-args $APPROVAL_SRV_ADDR
```

The `Deployed to` address should be assigned to `APPROVAL_RCT_ADDR`.

**NOTE**: We added `--value 0.1ether` to the deployment command above to fund the contract as the callback function requires the contract to hold an ETH balance. If the contract balance is insufficient, fund it by running the following command:

```bash
cast send $APPROVAL_RCT_ADDR --rpc-url $REACTIVE_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether
```

Alternatively, you can deposit funds into the [Reactive callback proxy contract](https://dev.reactive.network/origins-and-destinations) using this command:

```bash
cast send --rpc-url $REACTIVE_RPC --private-key $SEPOLIA_PRIVATE_KEY $CALLBACK_PROXY_ADDR "depositTo(address)" $APPROVAL_RCT_ADDR --value 0.1ether
```

### Step 2 — Demo Client Deployment

#### Token Deployment

Deploy the `ApprovalDemoToken` contract with the command given below. The constructor arguments are the name and symbol of the token you deploy. As an example, use the `"FTW"` value for both arguments.

```bash
forge create src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args "FTW" "FTW"
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

Transfer `1000` tokens (Service Fee in Wei) to the exchange contract:

```bash
cast send $EXCH_ADDR --value 1000 --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

#### Subscribe to Approval Service

Subscribe the exchange contract to the approval service:

```bash
cast send $EXCH_ADDR "subscribe()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

**NOTE**: Dynamic subscription to approval events takes about 30 seconds, roughly twice Sepolia's block interval plus Reactive's block interval, before the service starts processing approvals for the new subscriber.

### Step 4 — Test Approvals

Approve the transfer for `100` tokens (Tokens to exchange in Wei) and watch the magic happen:

```bash
cast send $TOKEN_ADDR "approve(address,uint256)" $EXCH_ADDR 100 --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

### Step 5 — Magic Swap Deployment

You can use two pre-deployed tokens or deploy your own (see the Token Deployment section).

```bash
export TOKEN1_ADDR=0x8Ef05EE16364310F17bE28c0AB571c1359d256A7
export TOKEN2_ADDR=0x1eDCd4d53A6d396cf91f17294AA39123DB6f12B4
```

You can request each token once as follows:

```bash
cast send $TOKEN1_ADDR "request()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

```bash
cast send $TOKEN2_ADDR "request()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

#### Token Deployment

Deploy two tokens with constructor arguments: `"TOKEN_NAME"` and `"TOKEN_SYMBOL"`. As an example, use `"TK1"` for both arguments of the first token and `"TK2"` for the second.

```bash
forge create src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args "TK1" "TK1"
```

The `Deployed to` address should be assigned to `TOKEN1_ADDR`.

```bash
forge create src/demos/approval-magic/ApprovalDemoToken.sol:ApprovalDemoToken --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args "TK2" "TK2"
```

The `Deployed to` address should be assigned to `TOKEN2_ADDR`.

#### Create Liquidity Pool

Create a liquidity pool for the two tokens using the pair factory contract address `0x7E0987E5b3a30e3f2828572Bb659A548460a3003`, which is a constant in this context.

```bash
cast send 0x7E0987E5b3a30e3f2828572Bb659A548460a3003 'createPair(address,address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $TOKEN1_ADDR $TOKEN2_ADDR
```

**NOTE**: Assign the pair address from transaction logs on [Sepolia scan](https://sepolia.etherscan.io/) to `PAIR_ADDR` or export the pre-made pair for the tokens above:

```bash
export PAIR_ADDR=0x18f95653b8593C5a1aB5D6f1EEd53A6e23e4AA68
```

#### Add liquidity

Transfer tokens to the pair:

```bash
cast send $TOKEN1_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $PAIR_ADDR 0.5ether
```
```bash
cast send $TOKEN2_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $PAIR_ADDR 0.5ether
```

Mint liquidity, using your EOA address (Client Wallet):

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
export SWAP_ADDR=0xD982d553725FCc5863D7E39E62F78fbB4d044b1C
```

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