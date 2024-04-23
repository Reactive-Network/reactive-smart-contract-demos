# Reactive Network Demo

## Overview

This demo simulates a basic use case of Reactive Network, employing two key capabilities:

* Low-latency monitoring of logs emitted by arbitrary contracts in L1 Network (Sepolia testnet in this case).
* Calls from Reactive Network to arbitrary L1 contracts.

```
+----------------------------------------------------------------+
| L1 network                                                     |
| +-------------------------+ +--------------------------------+ |
| | Source chain contract   | | Destination chain contract     | |
| | (BasicDemoL1Contract)   | | (BasicDemoL1Callback)          | |
| +-------------------------+ +--------------------------------+ |
+------------------|------------------^--------------------------+
                   | (emitted log)    | (callback)
+------------------|------------------|--------------------------+
| Reactive Net     |                  |                          |
|        +---------|------------------|--------------+           |
|        | ReactVM v                  |              |           |
|        |         +-----------------------------+   |           |
|        |         | Rective contract            |   |           |
|        |         | (BasicDemoReactiveContract) |   |           |
|        |         +-----------------------------+   |           |
|        +-------------------------------------------+           |
+----------------------------------------------------------------+
```
Fig. 1

In practical terms, this general use case can be applicable in any number of scenarios, from simple stop orders to fully decentralized algorithmic trading.

There are three main contracts involved in this scenario:

* Source chain contract.
* Reactive contract.
* Destination chain contract.

### Source chain contract

This contract, or set of contracts, presumably emits logs record of some interest to the Reactive Network user. In financial applications, this could be a DEX, such as a Uniswap pool, emitting data on trades and/or exchange rates. Typically, the contract is controlled by a third party, otherwise mediation by Reactive Network would be unnecessary.

In our demo this contract is implemented in `BasicDemoL1Contract.sol`. It's a very simple contract that accepts native transfers, emits log records about them, and returns the funds back to sender.

### Reactive contract

Reactive contracts implement the logic of event monitoring and initiating calls back to L1 chain(s). Reactive contracts are fully fledged EVM contracts that can maintain persistent state, statically or dynamically subscribe/unsubscribe to multiple different event sources, and perform callbacks by emitting speciliazed log records specifying the parameters of a transaction to be submitted to destination chain.

Reactive contracts execute in a private subnet (ReactVM) tied to a specific deployer address. This limits their ability to interact with other reactive contracts, but greatly improves Reactive Networks ability to scale.

In our demo, the reactive contract implemented in `BasicDemoReactiveContract.sol` subscribes to events emitted by `BasicDemoL1Contract.sol` on deployment. Whenever the observed contract reports receiving more than 0.1 ether in a single transfer, the reactive contract initiates an L1 callback by emitting a log record with requested transaction parameters and payload.

In a more practical application, this contract could be monitoring an exchange rate of a given token pair, issuing a buy or sell order once the rate crosses the specified threshold, thus implementing simple stop orders.

### Destination chain contract

This contract should implement the L1 part of the user's business logic. Note that while this could be under the user's direct control, it could also be a third party contract.

In our demo, the callback contract (`BasicDemoL1Callback.sol`) responds to invocation of its `callback()` method simply by emitting yet another log record.

Note that in real world applications the callback contract must somehow verify the validity of the call, by checking the message sender, and/or verifying the current rate when executing a stop order.

### Features not covered by the demo

The reactive contract in this demo does not employ the full range of cabalities already available in Reactive Network, notably:

* Subscription to multiple event sources. Apart from obvious usefulness of this capability, we expect that reactive contracts will often subscribe to logs of their own callback contracts, to ensure consistent state across networks.
* Dynamic subscriptions and unsubscriptions, through callbacks to Reactive Network itself.
* Persistent state. The demo contract does not maintain any meaningful state, reacting to every event in isolation.
* Arbitrary callbacks. Reactive contracts may generate arbitrary transaction payloads, while the demo contracts simply calls a predetermined method of a fixed contract.

## Deployment for testing

You will need the following enviornment variables configured appropriately to follow this script:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`
* `SYSTEM_CONTRACT_ADDR`

First of all, deploy the source chain contract to Sepolia:

```
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/basic/BasicDemoL1Contract.sol:BasicDemoL1Contract
```

Assign the deployment address to the environment variable `SOURCE_ADDR`.

Now deploy the callback contract to Sepolia:

```
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/basic/BasicDemoL1Callback.sol:BasicDemoL1Callback
```

Assign the deployment address to the environment variable `CALLBACK_ADDR`.

Finally, deploy the reactive contract, configuring it to listen to `SOURCE_ADDR`, and to send callbacks to `CALLBACK_ADDR`.

```
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/basic/BasicDemoReactiveContract.sol:BasicDemoReactiveContract --constructor-args $SYSTEM_CONTRACT_ADDR $SOURCE_ADDR 0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb $CALLBACK_ADDR
```

Test the whole setup by sending some SepETH to `SOURCE_ADDR`:

```
cast send $SOURCE_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.11ether
```

This should eventually result in a callback transaction to `CALLBACK_ADDR` being initiated by the Reactive Network.
