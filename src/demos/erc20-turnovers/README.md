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

Deploy the contracts to Ethereum Sepolia and Reactive Kopli by following these steps. Ensure the following environment variables are configured:

* `SEPOLIA_RPC` — RPC URL for Ethereum Sepolia, (see [Chainlist](https://chainlist.org/chain/11155111))
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — RPC URL for Reactive Kopli (https://kopli-rpc.rkt.ink).
* `REACTIVE_PRIVATE_KEY` — Reactive Kopli private key

[//]: # (* `SEPOLIA_CALLBACK_PROXY_ADDR` — 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8)

**Faucet**: To receive REACT tokens, send SepETH to the Reactive faucet at `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`. An equivalent amount of REACT will be sent to your address.

### Step 1 — Origin/Destination Contract

Deploy the `TokenTurnoverL1` contract and assign the `Deployed to` address from the response to `TURNOVER_L1_ADDR`.

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

### Step 2 — Reactive Contract

Deploy the `TokenTurnoverReactive` contract and assign the `Deployed to` address from the response to `TURNOVER_REACTIVE_ADDR`.

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/demos/erc20-turnovers/TokenTurnoverReactive.sol:TokenTurnoverReactive --constructor-args $TURNOVER_L1_ADDR
```

### Step 3 — Monitor Token Turnover

Use the USDT contract at `0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0` (or any active token) and send a request to `TURNOVER_L1_ADDR` to monitor its turnover. The contract will emit a log with the turnover data for the specified token shortly after the request.

```bash
cast send $TURNOVER_L1_ADDR "request(address)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0
```

### Step 4 — Reactive Contract State

To stop the reactive contract:

```bash
cast send $TURNOVER_REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```

To resume the reactive contract:

```bash
cast send $TURNOVER_REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY
```