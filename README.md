# Reactive Smart Contract Demos

## Development & Deployment Instructions

### Environment Setup

To set up `foundry` environment, run:

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

Install dependencies:

```bash
forge install
```

### Development & Testing

To compile artifacts:

```bash
forge compile
```

To run the test suite:

```bash
forge test -vv
```

To inspect the call tree:

```bash
forge test -vvvv
```

### Additional Documentation & Demos

Refer to [Docs](https://dev.reactive.network/system-contract) or [TECH.md](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/TECH.md) for additional information on implementing reactive contracts and callbacks. The `src/demos` directory contains several demos with their `README.md` files.

### Environment Variable Configuration

The following environment variables are used in the instructions for running the demos, and should be configured beforehand.

#### `SEPOLIA_RPC`

Ethereum Sepolia RPC URL, see [Chainlist](https://chainlist.org/chain/11155111).

#### `SEPOLIA_PRIVATE_KEY`

Ethereum Sepolia private key.

#### `REACTIVE_RPC`

Reactive Kopli RPC URL, see [Reactive Docs](https://dev.reactive.network/kopli-testnet#reactive-kopli-information).

#### `REACTIVE_PRIVATE_KEY`

Reactive Kopli private key.

#### `SYSTEM_CONTRACT_ADDR`

For the system contract address, refer to [Reactive Docs](https://dev.reactive.network/kopli-testnet#kopli-testnet-information).

#### `CALLBACK_PROXY_ADDR`

For callback proxy addresses, refer to [Reactive Docs](https://dev.reactive.network/origins-and-destinations#chains).
