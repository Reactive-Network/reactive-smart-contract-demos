# Uniswap V2 Exchange Rate History Demo

## Overview

This demo tracks and retrieves historical exchange rate data from Uniswap V2 liquidity pools using smart contracts. This involves deploying contracts on both the origin and reactive chains, subscribing to events, and handling synchronization and resynchronization requests.

## Origin Chain Contract

The `UniswapHistoryDemoL1` contract is designed to manage and track resynchronization requests and responses for Uniswap V2 liquidity pairs. When deployed, the contract sets the deploying address as the owner and initializes a callback sender address. This contract emits two key events: `RequestReSync` and `ReSync`.

The `RequestReSync` event is triggered when the owner requests resynchronization information for a specific Uniswap V2 pair by calling the `request` function. This function, restricted to the owner through the `onlyOwner` modifier, allows the owner to specify the pair address and the block number for which the resynchronization is needed.

The `ReSync` event is triggered by the `resync` function, which processes resynchronization data received from a reactive contract. This function is restricted to the predefined callback sender via the `onlyReactive` modifier, ensuring that only authorized entities can send resynchronization data. The `resync` function processes the data, emitting the `ReSync` event that provides the reserve details for the specified token pair at the given block number.

By enforcing these restrictions, the contract maintains the integrity and security of the historical exchange rate tracking process, ensuring that only authorized requests and callbacks are processed.

## Reactive Contract

The `UniswapHistoryDemoReactive` contract operates on the reactive chain and is designed to handle synchronization events for Uniswap V2 liquidity pairs. When deployed, the contract subscribes to relevant events on the Sepolia chain and processes the corresponding data, maintaining a history of reserves for each pair. It emits a `Sync` event when synchronization data for a Uniswap V2 pair is received, storing the reserves and block number for each synchronization.

The contract can function in two modes: as a standard reactive network contract or within a ReactVM environment. In the reactive network mode, the contract can be paused and resumed by the owner using the `pause` and `resume` functions, respectively. These functions manage the subscription to synchronization events to control data flow. In the ReactVM mode, the contract processes synchronization data through the `react` function. This function decodes the received data, updates the reserves history for the relevant pair, and emits a `Sync` event with the details of the reserves and block number. Additionally, the `react` function can handle resynchronization requests from the origin chain, processing historical data and preparing it for callback to the origin chain.

The contract enforces access control through several modifiers. The `onlyOwner` modifier restricts certain functions to the contract owner, ensuring that only authorized actions can be performed by the owner. The `rnOnly` modifier ensures that certain functions can only be called when the contract is operating in the reactive network mode, while the `vmOnly` modifier restricts functions to the ReactVM mode.

These access controls maintain the integrity and security of the contract's operations, ensuring that only authorized entities can manage synchronization and resynchronization processes.

## Destination Chain Contract

Although the demo primarily involves the `UniswapHistoryDemoL1` and `UniswapHistoryDemoReactive` contracts, the concept of a destination contract can be abstractly considered as the endpoint that receives and processes the resynchronization data provided by the reactive contract. In practice, the `UniswapHistoryDemoL1` contract itself acts as the destination for the resynchronization data callback.

By acting as both the origin for resynchronization requests and the destination for the processed data, the `UniswapHistoryDemoL1` contract ensures a cohesive and efficient workflow. This dual-role functionality eliminates the need for a separate destination contract, simplifying the architecture and making the entire resynchronization process easier to manage.

## Further Considerations

While the Uniswap V2 Exchange Rate History Demo effectively monitors historical exchange rates across chains, there are several improvements that can optimize the capabilities of the Reactive Network.

- Enhanced Subscription Management: Introducing support for subscriptions to multiple origin contracts, enabling monitoring of various liquidity pairs simultaneously.

- Real-time Configuration: Implementing dynamic subscription and unsubscription mechanisms to adjust monitored contracts in real time. This flexibility enhances responsiveness and adaptability to changing market conditions.

Moreover, maintaining a persistent state can offer valuable historical context, maintaining the reliability of data retrieval and analysis. Adopting dynamic transaction payloads instead of static callbacks can further simplify interactions, supporting more intricate processes and automation within decentralized exchanges (DEXes). These changes can enhance the functionality of reactive smart contracts in managing Uniswap V2 exchange rate histories across blockchains.

## Deployment & Testing

To deploy and test the contracts, follow these steps. Ensure the following environment variables are configured appropriately:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SYSTEM_CONTRACT_ADDR`

You can use the recommended Sepolia RPC URL: `https://rpc2.sepolia.org`.

### Step 1

Deploy the origin chain contract and assign the contract address from the response to `UNISWAP_L1_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoL1.sol:UniswapHistoryDemoL1 --constructor-args 0x0000000000000000000000000000000000000000
```

### Step 2

Deploy the reactive contract and assign the contract address from the response to `UNISWAP_REACTIVE_ADDR`.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-history/UniswapHistoryDemoReactive.sol:UniswapHistoryDemoReactive --constructor-args $SYSTEM_CONTRACT_ADDR $UNISWAP_L1_ADDR
```

### Step 3

Monitor the contract's activity by selecting an active pair address and assigning it to `ACTIVE_PAIR_ADDR`. Then, specify the desired block number and assign it to `BLOCK_NUMBER`.

Send a data request to the Sepolia contract:

```bash
cast send $UNISWAP_L1_ADDR "request(address,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $ACTIVE_PAIR_ADDR $BLOCK_NUMBER
```

The contract should emit a log record with the collected turnover data of the specified token shortly thereafter.

### Step 4

To stop the reactive contract:

```bash
cast send $UNISWAP_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```bash
cast send $UNISWAP_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```
