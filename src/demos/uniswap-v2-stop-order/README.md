# Uniswap V2 Stop Order Demo

## Overview

```mermaid
%%{ init: { 'flowchart': { 'curve': 'basis' } } }%%
flowchart LR
    subgraph Reactive Network
        subgraph ReactVM
            RC(Reactive Contract)
        end
    end
    subgraph L1 Network
        OCC(Origin Chain Contract)
        DCC(Destination Chain Contract)
    end
OCC -.->|emitted log| RC
RC -.->|callback| DCC
```

This demo builds on the basic reactive example presented in `src/demos/basic/README.md`. Refer to that document for an outline of fundamental concepts and the architecture of reactive applications. The demo implements simple stop orders for Uniswap V2 liquidity pools. The application monitors a specified Uniswap V2 pair, and as soon as the exchange rate reaches a given threshold, it initiates a sale of assets through that same pair.

## Origin Chain Contract

The `UniswapDemoToken` contract is a basic implementation of an ERC-20 token using OpenZeppelin's standard library. It initializes the token with a name and symbol provided during deployment. Upon deployment, 100 tokens (with 18 decimals) are minted and assigned to the contract deployer's address. The contract includes comments with addresses for the Uniswap router and factory for reference, indicating potential integration points for token swaps and liquidity provision.

## Reactive Contract

The `UniswapDemoStopOrderReactive` contract is an advanced example of a reactive contract designed for use with the Uniswap V2 protocol and the Reactive Network. This contract subscribes to events from both a Uniswap V2 pair contract and a stop order contract on Sepolia. When an event matching specific conditions occurs, it triggers a callback to execute a stop order.

The contract defines a structure `Reserves` to hold the reserve amounts of the Uniswap V2 pair. It has multiple events to signal various states and actions, such as `Subscribed`, `VM`, `AboveThreshold`, `CallbackSent`, and `Done`. The contract uses `REACTIVE_IGNORE` (`0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad`) to ignore specific topics. It employs `0` for chain ID and contract address parameters to achieve the same purpose, ensuring clarity in its event subscriptions.

The constructor sets up the initial state, including the reactive network subscription to the Uniswap V2 pair and stop order contracts. It stores addresses and parameters such as the token pair, stop order, client, token order type, coefficient, and threshold for the stop order.

The `react` function is the core of the contract, which processes events from the reactive network. It asserts the contract is not in the done state and processes events either from the stop order contract or the Uniswap V2 pair contract. When a sync event is received from the Uniswap V2 pair, it checks if the reserves are below the specified threshold. If so, it triggers a stop order. The function `below_threshold` determines if the reserves meet the conditions for triggering the stop order based on the predefined coefficient and threshold.

## Destination Chain Contract

The `UniswapDemoStopOrderCallback` contract is designed to facilitate stop order functionality on Uniswap V2 pairs through reactive callbacks. It includes a constructor to initialize the callback sender and the Uniswap V2 Router address. The contract uses the `onlyReactive` modifier to restrict function access to authorized callers, ensuring security.

The `UniswapDemoStopOrderCallback` contract is designed to enable the execution of stop orders on the Uniswap V2 pairs through Reactive callbacks. It initializes with parameters `_callback_sender` and `_router`, ensuring secure access and enabling token swaps through the Uniswap V2 Router contract. Access control is enforced through the `onlyReactive` modifier, restricting critical functions to authorized addresses defined during deployment.

The `stop` function is invoked upon receiving a trigger from the Reactive Network. It processes parameters including the Uniswap V2 pair address (`pair`), client address (`client`), a boolean (`is_token0`) indicating the token type being sold, and specific thresholds (`coefficient` and `threshold`) defining stop order conditions.

Internally, the `below_threshold` function evaluates whether current Uniswap V2 pair reserves meet predefined criteria for executing stop orders. Depending on the boolean `token0`, it calculates the rate based on reserves and checks if it falls below the defined threshold, ensuring accurate decision-making for order execution.

Transaction execution involves verifying the client's token allowance and balance for the sell token, followed by executing a precise token swap using the Uniswap V2 Router (`router`). Upon successful completion, resulting tokens are transferred back to the client's address, signaling completion through the `Stop` event, which includes details of the pair, client, token, and transaction outcomes.

Throughout, constants like `DEADLINE` set a timestamp for transaction validity, ensuring timely execution and reliability in processing token swaps. The callback contract is stateless and may be used by any number of reactive stop order contracts as long as they use the same router contract.

## Further Considerations

While this demo covers a realistic use case, it is not a production-grade implementation, which would require more safety and sanity checks as well as a more complicated flow of state for its reactive contract. This demo is intended to show additional features of the Reactive Network compared to the basic demo, namely:

* Subscription to heterogeneous events.

* Stateful reactive contracts.

* Loopback data flow between the reactive contract and the destination chain contract.

* Basic sanity checks required in destination chain contracts, both for security reasons and because callback execution is not synchronous with the execution of the reactive contract.

Nonetheless, a few further improvements could be made to bring this implementation closer to a practical stop order one:

* Leveraging dynamic event subscription to allow a single reactive contract to handle multiple arbitrary orders.

* Adding more sanity checks and a retry policy in the reactive contract.

* Supporting arbitrary routers on the destination side.

* Implementing a more elaborate data flow between the reactive contract and the destination chain contract.

* Supporting alternate DEXes.

## Deployment & Testing

This script guides you through deploying and testing the Uniswap V2 stop order demo on the Sepolia Testnet. Ensure the following environment variables are configured appropriately before proceeding with this script:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SYSTEM_CONTRACT_ADDR`

To test this live, you will need some testnet tokens and a Uniswap V2 liquidity pool for them. Use any pre-existing tokens and pair or deploy your own, e.g., the barebones ERC-20 token provided in `UniswapDemoToken.sol`. You can use the recommended Sepolia RPC URL: `https://rpc2.sepolia.org`.

### Step 1

Deploy two ERC-20 tokens. The constructor arguments are the token name and token symbol, which you can choose as you like. Upon creation, the token mints and transfers 100 units to the deployer.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args $TOKEN_NAME $TOKEN_SYMBOL
```

Repeat the above command for the second token with a different name and symbol:

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoToken.sol:UniswapDemoToken --constructor-args $TOKEN_NAME $TOKEN_SYMBOL
```

### Step 2

Create a Uniswap V2 pair (pool) using the token addresses created in Step 1. Note that the smaller address in hexadecimal is `token0` and the other is `token1`. Use the `PAIR_FACTORY_CONTRACT` address `0x7E0987E5b3a30e3f2828572Bb659A548460a3003`.

```bash
cast send $PAIR_FACTORY_CONTRACT 'createPair(address,address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $TOKEN0_ADDR $TOKEN1_ADDR
```

### Step 3

Deploy the destination chain contract to Sepolia. It is configured to use the Uniswap V2 router at `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008` associated with the factory contract at `0x7E0987E5b3a30e3f2828572Bb659A548460a3003`.

If you intend to use the pairs deployed by this factory, there is no need to deploy your own instance of the contract. In case you do require your own destination chain contract, deploy as follows:

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderCallback.sol:UniswapDemoStopOrderCallback --constructor-args $AUTHORIZED_CALLER_ADDRESS $UNISWAP_V2_ROUTER_ADDRESS
```

`AUTHORIZED_CALLER_ADDRESS`: The address authorized for callbacks (use `0x0000000000000000000000000000000000000000` to skip check).

`UNISWAP_V2_ROUTER_ADDRESS`: The Uniswap V2 router address.

### Step 4

Transfer some liquidity into the created pool. Note that you won't get its address immediately after `createPair()`. Get the newly created pair address from the transaction logs on [Sepolia scan](https://sepolia.etherscan.io/) where the `PairCreated` event is emitted.

```bash
cast send $TOKEN0_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CREATED_PAIR_ADDR 10000000000000000000
```

```bash
cast send $TOKEN1_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CREATED_PAIR_ADDR 10000000000000000000
```

```bash
cast send $CREATED_PAIR_ADDR 'mint(address)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $SEPOLIA_ADDR
```

### Step 5

Deploy the reactive stop order contract to the Reactive Network as follows:

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderReactive.sol:UniswapDemoStopOrderReactive --constructor-args $SYSTEM_CONTRACT_ADDRESS $CREATED_PAIR_ADDR $CALLBACK_CONTRACT_ADDRESS $SEPOLIA_ADDR $DIRECTION_BOOLEAN $EXCHANGE_RATE_DENOMINATOR $EXCHANGE_RATE_NUMERATOR
```

`SYSTEM_CONTRACT_ADDRESS`: The system contract that handles event subscriptions.

`CREATED_PAIR_ADDR`: The Uniswap pair address from Step 2.

`CALLBACK_CONTRACT_ADDRESS`: The contract address from Step 3.

`SEPOLIA_ADDR`: The client's address initiating the order.

`DIRECTION_BOOLEAN`: `true` to sell `token0` and buy `token1`; `false` for the opposite.

`EXCHANGE_RATE_DENOMINATOR` and `EXCHANGE_RATE_NUMERATOR`: Integer representation of the exchange rate threshold below which a stop order is executed. These variables are set this way because the EVM works only with integers. As an example, to set the threshold at 1.234, the numerator should be 1234 and the denominator should be 100.

### Step 6

To initiate a new stop order, authorize the destination chain contract to spend your tokens:

```bash
cast send $TOKEN_ADDRESS 'approve(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CALLBACK_CONTRACT_ADDR 1000000000000000000
```

The last parameter is the raw amount you intend to authorize. For tokens with 18 decimal places, the above example allows the callback to spend one token.

### Step 7

After creating the pair and adding liquidity, we have to make the reactive smart contract work by adjusting the exchange rate directly through the pair, not the periphery.

Liquidity pools are rather simple and primitive contracts. They do not offer much functionality or protect the user from mistakes, making their deployment cheaper. That's why most users perform swaps through so-called peripheral contracts. These contracts are deployed once and can interact with any pair created by a single contract. They offer features to limit slippage, maximize swap efficiency, and more.

However, since our goal is to change the exchange rate, these sophisticated features are a hindrance. Instead of swapping through the periphery, we perform an inefficient swap directly through the pair, achieving the desired rate shift.

```bash
cast send $TOKEN0_ADDR 'transfer(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CREATED_PAIR_ADDR 20000000000000000
```

The following command executes a swap at a highly unfavorable rate, causing an immediate and significant shift in the exchange rate:

```bash
cast send $CREATED_PAIR_ADDR 'swap(uint,uint,address,bytes calldata)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY 0 5000000000000000 $SEPOLIA_ADDR "0x"
```

After that, the stop order will be executed and visible on [Sepolia scan](https://sepolia.etherscan.io/).