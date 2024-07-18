# ERC-721 Ownership Demo

## Overview

The demo implements an ownership tracking system for ERC-721 tokens. The application monitors specified ERC-721 contracts and, upon detecting an ownership change or request, updates and synchronizes the ownership data across the involved chains. The demo builds on the basic reactive example outlined in `src/demos/basic/README.md`. Refer to that document for understanding the fundamental concepts and architecture of reactive applications.

## Origin Chain Contract

The `NftOwnershipL1` contract is designed to manage and track ownership requests and responses for ERC-721 tokens. When deployed, it sets the deploying address as the contract owner and initializes a callback sender address. The contract emits two types of events: `Request` and `Ownership`.

The `Request` event is triggered when the owner requests ownership information for a specific token by calling the `request` function, which is restricted to the owner through the `onlyOwner` modifier.

The `Ownership` event is triggered by the `callback` function, which receives ownership data from a reactive contract. This function is restricted to the predefined callback sender via the `onlyReactive` modifier. The `callback` function processes the ownership data and emits the `Ownership` event, providing the collected ownership information for the specified token. 

The contract ensures that only authorized entities can make requests and callbacks, maintaining the integrity and security of the ownership tracking process.

## Reactive Contract

The `NftOwnershipReactive` contract is designed to track and manage ownership transfers of ERC-721 tokens. Upon deployment, it sets up the contract owner and establishes a connection with a subscription service for monitoring events. The contract listens for ERC-721 transfer events and specific request events from the `NftOwnershipL1` contract.

When a transfer event is detected, it records the new owner of the token and emits an `OwnershipTransfer` event. The `react` function is crucial as it handles these detected events. If an ERC-721 transfer event is identified, it updates the ownership mapping and emits the transfer event. For request events from `NftOwnershipL1`, it prepares a callback payload with the current ownership information and emits a `Callback` event to the origin contract.

The contract includes functionalities to pause and resume its operations, restricting these actions to the owner. The `pause` and `resume` functions manage the subscription to the transfer events, enabling the contract to halt or continue monitoring as needed.

It also distinguishes between methods that should only be executed in a reactive network environment (`rnOnly` modifier) and those meant for a ReactVM environment (`vmOnly` modifier). This ensures that the contract operates correctly based on its deployment context.

The internal `owners` function retrieves the list of recorded owners for a specified token, enabling the contract to provide accurate ownership history when requested. This comprehensive tracking and reactive functionality make `NftOwnershipReactive` a solution for managing ERC-721 token ownership in a decentralized environment.

## Destination Chain Contract

Although the demo primarily involves the `NftOwnershipL1` and `NftOwnershipReactive` contracts, the concept of a destination contract can be abstractly considered as the endpoint that receives and processes the ownership data provided by the reactive contract. In practice, the `NftOwnershipL1` contract itself acts as the destination for the ownership data callback.

## Further Considerations

The demo covers the basic functionality of tracking ERC-721 ownership across chains but does not fully leverage the Reactive Network's capabilities. Additional features include multi-origin subscriptions for extensive event tracking and dynamic subscriptions/unsubscriptions.

Maintaining a persistent state would provide historical data context, thereby enhancing reliability. Moreover, generating arbitrary transaction payloads instead of fixed callbacks could enable more complex interactions. Exploring these extra features can significantly improve the capabilities of reactive smart contracts.

## Deployment & Testing

To deploy and test the contracts, follow these steps. Ensure the following environment variables are configured appropriately:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SYSTEM_CONTRACT_ADDR`

You can use the recommended Sepolia RPC URL: `https://rpc2.sepolia.org`.

### Step 1

Deploy the origin chain contract and assign the contract address from the response to `OWNERSHIP_L1_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipL1.sol:NftOwnershipL1 --constructor-args 0x0000000000000000000000000000000000000000
```

### Step 2

Deploy the reactive contract and assign the contract address from the response to `OWNERSHIP_REACTIVE_ADDR`.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc721-ownership/NftOwnershipReactive.sol:NftOwnershipReactive --constructor-args $SYSTEM_CONTRACT_ADDR $OWNERSHIP_L1_ADDR
```

### Step 3

Select a token contract address with some activity to monitor and assign it to `ACTIVE_TOKEN_ADDR`. Also, assign a specific token ID to `ACTIVE_TOKEN_ID`. Then, send a data request to the Sepolia contract.

```bash
cast send $OWNERSHIP_L1_ADDR "request(address,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $ACTIVE_TOKEN_ADDR $ACTIVE_TOKEN_ID
```

The contract should emit a log record with the collected turnover data of the specified token shortly thereafter.

### Step 4

To stop the reactive contract:

```bash
cast send $OWNERSHIP_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```bash
cast send $OWNERSHIP_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
