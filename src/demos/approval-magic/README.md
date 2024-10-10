# Approval Magic Demo

## Overview

The **Approval Magic Demo** extends reactive and subscription-based concepts to implement an approval-based token exchange across multiple chains. The provided smart contracts facilitate token transfers and swaps by monitoring token approvals and reacting accordingly. The demo shows how an approval service integrated with the Reactive Network manages and executes cross-chain token exchanges, with each smart contract serving a distinct role in the overall workflow.

## Contracts

- **Subscription-Based Approval Service:** [ApprovalService](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/approval-magic/ApprovalService.sol) manages subscription services, processes approval callbacks, and settles gas fees, updating subscription status based on transaction outcomes and emitting `Subscribe` and `Unsubscribe` events.

- **Reactive Contract:** [ApprovalListener](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/approval-magic/ApprovalListener.sol) interacts with `ISubscriptionService` and `ApprovalService` to manage subscriptions and handle reactive network events, triggering actions like approval handling and subscription updates.

- **Token Initialization and Distribution:** [ApprovalDemoToken](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/approval-magic/ApprovalDemoToken.sol) is an ERC-20 token contract that mints 100 tokens to the deployer and allows additional token requests (1 Ether each) through the `request()` function. A `recipients` mapping ensures each address can only request tokens once.

- **Token Exchange:** [ApprovalEthExch](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/approval-magic/ApprovalEthExch.sol) manages token exchange approvals and settlements, interacting with `ApprovalService` and ERC-20 tokens. It includes owner access control, subscription management, and secure token transfers through approval callbacks.

- **Automated Token Swaps:** [ApprovalMagicSwap](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/approval-magic/ApprovalMagicSwap.sol) facilitates token swaps between two ERC-20 tokens via Uniswap V2, using subscription-based approvals from `ApprovalService` to manage and execute these swaps.

## Further Considerations

Deploying these smart contracts in a live environment involves addressing key considerations:

- **Security:** Ensuring security measures for token approvals and transfers to prevent unauthorized access.
- **Scalability:** Managing a high volume of subscribers and transactions to maintain performance.
- **Gas Optimization:** Reducing gas costs associated with approval handling to improve economic viability.
- **Interoperability:** Expanding support to a wider range of tokens and networks to improve versatility.

## Deployment & Testing

To deploy the contracts to Ethereum Sepolia and Kopli Testnet, follow these steps. Replace the relevant keys, addresses, and endpoints as needed. Make sure the following environment variables are correctly configured before proceeding:

* `SEPOLIA_RPC` — https://rpc2.sepolia.org
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — https://kopli-rpc.rkt.ink
* `SEPOLIA_CALLBACK_PROXY_ADDR` — 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8
* `KOPLI_CALLBACK_PROXY_ADDR` — 0x0000000000000000000000000000000000FFFFFF
* `CLIENT_WALLET` — Deployer's EOA wallet address 

**IMPORTANT**: The following assumes that `ApprovalService` and `ApprovalListener` are deployed using the same private key. `ApprovalDemoToken` and `ApprovalEthExch` can use other keys if needed.

**Note**: To receive REACT, send SepETH to the Reactive faucet on Ethereum Sepolia (`0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`). An equivalent amount will be sent to your address.

### Step 1 — Service Deployment

Current deployment addresses that can be reused:

```bash
export APPROVAL_SRV_ADDR=0x75eF46a6C6C6f59d282ffBA47F1066c43A9e9D55
export APPROVAL_RCT_ADDR=0x6f1b2380946E6F54a08A38d2475a05090CaE0c36
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

**NOTE**: To ensure a successful callback, `APPROVAL_SRV_ADDR` must have an ETH balance. Find more details [here](https://dev.reactive.network/system-contract#callback-payments). To fund the contract, run the following command:

```bash
cast send $APPROVAL_SRV_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether
```

To cover the debt of `APPROVAL_SRV_ADDR`, run this command:

```bash
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $APPROVAL_SRV_ADDR "coverDebt()"
```

Alternatively, you can deposit funds into the [Callback Proxy](https://dev.reactive.network/origins-and-destinations) contract on Sepolia, using the command below. The EOA address whose private key signs the transaction pays the fee.

```bash
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $SEPOLIA_CALLBACK_PROXY_ADDR "depositTo(address)" $APPROVAL_SRV_ADDR --value 0.1ether
```

#### Reactive Deployment

Deploy the `ApprovalListener` contract with the command shown below. Make sure to use the same private key (`SEPOLIA_PRIVATE_KEY`). Both contracts must be deployed from the same address as this ensures that the Sepolia contract can authenticate the RVM ID for callbacks.

```bash
forge create src/demos/approval-magic/ApprovalListener.sol:ApprovalListener --rpc-url $REACTIVE_RPC --private-key $SEPOLIA_PRIVATE_KEY --constructor-args $APPROVAL_SRV_ADDR
```

The `Deployed to` address should be assigned to `APPROVAL_RCT_ADDR`.

**NOTE**: To ensure a successful callback, `APPROVAL_RCT_ADDR` must have an ETH balance. Find more details [here](https://dev.reactive.network/system-contract#callback-payments). To fund the contract, run the following command:

```bash
cast send $APPROVAL_RCT_ADDR --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY --value 0.1ether
```

To cover the debt of `APPROVAL_RCT_ADDR`, run this command:

```bash
cast send --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY $APPROVAL_RCT_ADDR "coverDebt()"
```

Alternatively, you can deposit funds into the [Callback Proxy](https://dev.reactive.network/origins-and-destinations) contract on Kopli Testnet, using the command below. The EOA address whose private key signs the transaction pays the fee.

```bash
cast send --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY $KOPLI_CALLBACK_PROXY_ADDR "depositTo(address)" $APPROVAL_RCT_ADDR --value 0.1ether
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
export TOKEN1_ADDR=0xC1FC32C2Ba7dbB4BFFE2FDcdcc2090fF01662b70
export TOKEN2_ADDR=0xC6f44cda01b64bB05993Fe2b443Da91B206403de
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
export PAIR_ADDR=0x2EC44D4cD9afFdB64509Dc3C8c7b8Db62a1FDB27
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
export SWAP_ADDR=0xfC32e1a0a1ce26f354A8C7B6dA4Bf963304FA5a0
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