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

The stop order application subscribes to `Sync` log records produced by a given Uniswap V2 token pair contract, typically emitted on swaps, and deposition or withdrawal of liquidity from the pool. Additionally, the reactive contract subscribes to events from its own callback contract to deactivate the stop order on completion. We anticipate this loopback of events from the callback contract to be a crucial element in many reactive applications.

## Reactive Contract

The reactive contract for stop orders subscribes to the specified L1 pair contract. The received `Sync` events enable the reactive contract to compute the current exchange rate for the two tokens in the pool. Once the rate reaches the threshold given on the contract's deployment, it requests a callback to L1 to sell the assets.

Upon initiating the order's execution, the reactive contract begins waiting for the `Stop` event from the L1 contract(which serves as both origin and destination in this case), indicating successful completion of the order. After receiving that, the reactive contract goes dormant, reverting all calls to it. Unlike the simple contract in the basic demo, this reactive contract is stateful.

The reactive contract is fully configurable and can be used with any Uniswap V2-compatible pair contract. The reactive contract for this demo is implemented in `UniswapDemoStopOrderReactive.sol`.

## Destination Chain Contract

This contract is responsible for the actual execution of the stop order. The client is required to allocate the token allowance for the callback contract and ensure they have sufficient tokens for executing the order. Upon the Reactive Network executing the callback transaction, this contract verifies the caller's address to prevent misuse or abuse, checks the current exchange rate against the given threshold, confirming the allowance, and validating the token balance. Then it initiates an exact token swap through the Uniswap V2 router contract, returning the earned tokens to the client. Following the successful execution of the order, the callback contract emits a `Stop` log record picked up by the reactive contract, as described in the section above.

The callback contract is stateless and may be used by any number of reactive stop order contracts, as long as they use the same router contract. The callback contract is implemented in `UniswapDemoStopOrderCallback.sol`.

## Further Considerations

While this demo covers a realistic use case, it is not a production-grade implementation, which would require more safety and sanity checks as well as a more complicated flow of state for its reactive contract. This demo is intended to showcase additional features of the Reactive Network compared to the basic demo, namely:

* Subscription to heterogeneous L1 events.

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

You will need the following environment variables configured appropriately to follow this script:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SYSTEM_CONTRACT_ADDR`

If you want to test this live, you will need some tokens and a Uniswap V2 liquidity pool for them. You can use any pre-existing tokens and pair, or you can deploy your own, e.g., the barebones ERC-20 token provided in `UniswapDemoToken.sol`.

The destination chain contract is deployed to Sepolia at `0x7B7FDD139DaCF06d236C999E23cF2eac36C349C1`. It is configured to use the Uniswap V2 router at `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`, which is associated with the factory contract at `0x7E0987E5b3a30e3f2828572Bb659A548460a3003`. It doesn't validate the caller's address to simplify testing. If you can use the pairs deployed by this factory, there is no need to deploy your own instance of the contract. In case you do require your own destination chain contract, deploy as follows:

```
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderCallback.sol:UniswapDemoStopOrderCallback --constructor-args $AUTHORIZED_CALLER_ADDRESS $UNISWAP_V2_ROUTER_ADDRESS
```

Here, the `AUTHORIZED_CALLER_ADDRESS` should contain the address you intend to authorize for performing callbacks or use`0x0000000000000000000000000000000000000000` to skip this check. `UNISWAP_V2_ROUTER_ADDRESS` should point to the V2-compatible router you plan to work with.

To initiate a new stop order, you should authorize your destination chain contract to spend your tokens:

```
cast send $TOKEN_ADDRESS 'approve(address,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_EY $CALLBACK_CONTRACT_ADDR 1000000000000000000
```

The last parameter is the raw amount you intend to authorize. For tokens with 18 decimal places, the above is equivalent to allowing the callback to spend a single token.

Now, deploy the reactive stop order contract to the Reactive Network:

```
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/uniswap-v2-stop-order/UniswapDemoStopOrderReactive.sol:UniswapDemoStopOrderReactive --constructor-args $SYSTEM_CONTRACT_ADDRESS $UNISWAP_V2_PAIR_ADDRESS $CALLBACK_CONTRACT_ADDRESS $CLIENT_WALLET $DIRECTION_BOOLEAN $EXCHANGE_RATE_DENOMINATOR $EXCHANGE_RATE_NUMERATOR
```

The `SYSTEM_CONTRACT_ADDR` should point to the system contract handling event subscriptions.

The `SYSTEM_CONTRACT_ADDR` should point to the system contract handling event subscriptions. The rest of the variables should be self-explanatory, except for `DIRECTION_BOOLEAN`, which specifies whether the order is for selling `token0` or `token1` of the pair in question.

You're all set!

Performing the swaps through the pair being monitored, you should be able to bring the exchange rate below the threshold, initiating the execution of your stop order.

Users may want to test separate components manually, feeding events to the reactive contract, or activating the callback manually:

```
cast call $REACTIVE_CONTRACT_ADDRESS 'react(uint256,address,uint256,uint256,uint256,uint256,bytes)' --trace --verbose --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY 0 0xED32ba8b09Ced902b1c49E2a1F384AfC98C1330C 0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1 0 0 0 0x00000000000000000000000000000000000000000000000098a7d9b8314c000000000000000000000000000000000000000000000000000083d6c7aab6360000
```

The parameters being fed to the `react()` method include:

* Chain ID, which can normally be ignored while testing.

* Origin contract's address, set to the monitored pair's address in the example above.

* The four topics of the log record, with the example above corresponding to the Uniswap V2's `Sync` event.

* Payload, containing the pair's remaining reserves for the `Sync` event. These could be encoded by using any ABI lib or pulled from an actual `Sync` event using any block explorer software.

Assuming the exchange rate is below the threshold, the `call` should produce a trace similar to the following:

```
Traces:
  [20319] 0x0c189A26E0AD06f8E12179280d9e8fB0EE1648C2::90dfa8f4(0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ed32ba8b09ced902b1c49e2a1f384afc98c1330c1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000098a7d9b8314c000000000000000000000000000000000000000000000000000083d6c7aab6360000)
    ├─  emit topic 0: 0x8dd725fa9d6cd150017ab9e60318d40616439424e2fade9c1c58854950917dfc
    │       topic 1: 0x0000000000000000000000000000000000000000000000000000000000000000
    │       topic 2: 0x0000000000000000000000007b7fdd139dacf06d236c999e23cf2eac36c349c1
    │       topic 3: 0x00000000000000000000000000000000000000000000000000000000000f4240
    │           data: 0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a40ac73c12000000000000000000000000ed32ba8b09ced902b1c49e2a1f384afc98c1330c000000000000000000000000afefa3fec75598e868b8527231db8c431e51c2ae00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000
    └─ ← ()
```

This log record indicates to the Reactive Network that the contract wants to perform a callback to L1. See the technical reference for more details.

Calling the destination chain contract is quite straightforward:

```
cast send $CALLBACK_CONTRACT_ADDRESS 'stop(address,address,bool,uint256,uint256)' --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $UNISWAP_V2_PAIR_ADDRESS $CLIENT_WALLET $DIRECTION_BOOLEAN $EXCHANGE_RATE_DENOMINATOR $EXCHANGE_RATE_NUMERATOR
```

Here, the environment variables are the same as in the example above for deploying the reactive contract. Note that the destination chain contract is unaware of the contracts deployed to the Reactive Network. As long as the call passes the caller address check and there is both an allowance in specified tokens from the `$CLIENT_WALLET` and sufficient tokens to their name, the callback contract will happily perform any sale below the specified rate.