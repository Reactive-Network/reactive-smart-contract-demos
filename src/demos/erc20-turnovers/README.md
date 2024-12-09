# ERC-20 Turnovers Demo

## Overview

The **ERC-20 Turnovers Demo** tracks ERC-20 token turnovers across all contracts, providing the relevant data on request. This demo extends the principles introduced in the [Reactive Network Demo](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/main/src/demos/basic) and highlights two primary functionalities:

- **Turnover Monitoring:** Observes token transfers to accumulate and report turnover data.
- **Reactive Data Calls:** Provides real-time turnover information via callbacks to the origin contract.

## Contracts

- **Origin/Destination Chain Contract:** [TokenTurnoverL1](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/erc20-turnovers/TokenTurnoverL1.sol) manages turnover requests and responses for ERC-20 tokens, allowing the owner to request turnover data, which is then processed and returned by the reactive contract via callbacks.

- **Reactive Contract:** [TokenTurnoverReactive](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/src/demos/erc20-turnovers/TokenTurnoverReactive.sol) listens for ERC-20 transfer events and specific requests from `TokenTurnoverL1`. It updates turnover records and responds to requests by emitting callbacks with current turnover data.

## Further Considerations

There are several opportunities for improvement:

- **Multi-Origin Subscriptions:** Expand to monitor multiple contracts for event tracking.
- **Dynamic Subscriptions:** Enable real-time adjustments to subscriptions, allowing flexible and responsive tracking.
- **Persistent State Management:** Maintain historical data context to improve reliability.
- **Dynamic Callbacks:** Use arbitrary transaction payloads for more complex interactions and automation.

## Deployment & Testing

To deploy the contracts to Ethereum Sepolia and Kopli Testnet, follow these steps. Replace the relevant keys, addresses, and endpoints as needed. Make sure the following environment variables are correctly configured before proceeding:

* `SEPOLIA_RPC` — https://ethereum-sepolia-rpc.publicnode.com/ or https://1rpc.io/sepolia
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — https://kopli-rpc.rkt.ink
* `REACTIVE_PRIVATE_KEY` — Kopli Testnet private key
* `SEPOLIA_CALLBACK_PROXY_ADDR` — 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8

**Note**: To receive REACT, send SepETH to the Reactive faucet on Ethereum Sepolia (`0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`). An equivalent amount will be sent to your address.

### Step 1

Deploy the origin chain contract and assign the contract address from the response to `TURNOVER_L1_ADDR`.

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/erc20-turnovers/TokenTurnoverL1.sol:TokenTurnoverL1 --constructor-args 0x0000000000000000000000000000000000000000
```

[//]: # (#### Callback Payment)

[//]: # ()
[//]: # (To ensure a successful callback, the callback contract must have an ETH balance. Find more details [here]&#40;https://dev.reactive.network/system-contract#callback-payments&#41;. To fund the contract, run the following command:)

[//]: # ()
[//]: # (```bash)

[//]: # (cast send $TURNOVER_L1_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether)

[//]: # (```)

[//]: # ()
[//]: # (To cover the debt of the callback contact, run this command:)

[//]: # ()
[//]: # (```bash)

[//]: # (cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $TURNOVER_L1_ADDR "coverDebt&#40;&#41;")

[//]: # (```)

[//]: # ()
[//]: # (Alternatively, you can deposit funds into the [Callback Proxy]&#40;https://dev.reactive.network/origins-and-destinations&#41; contract on Sepolia, using the command below. The EOA address whose private key signs the transaction pays the fee.)

[//]: # ()
[//]: # (```bash)

[//]: # (cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $SEPOLIA_CALLBACK_PROXY_ADDR "depositTo&#40;address&#41;" $TURNOVER_L1_ADDR --value 0.1ether)

[//]: # (```)

### Step 2

Deploy the reactive contract and assign the contract address from the response to `TURNOVER_REACTIVE_ADDR`:

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc20-turnovers/TokenTurnoverReactive.sol:TokenTurnoverReactive --constructor-args $TURNOVER_L1_ADDR
```

### Step 3

Select a token contract address with some activity to monitor and assign it to `ACTIVE_TOKEN_ADDR`. Send a data request to the Sepolia contract. You can use the USDT contract as your active token address `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0`.

```bash
cast send $TURNOVER_L1_ADDR "request(address)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $ACTIVE_TOKEN_ADDR
```

The contract should emit a log record with the collected turnover data of the specified token shortly thereafter.

### Step 4

To stop the reactive contract:

```bash
cast send $TURNOVER_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```bash
cast send $TURNOVER_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```