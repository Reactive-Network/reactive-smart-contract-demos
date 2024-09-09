# System Smart Contracts for Reactive Network

## Development & Deployment Instructions

### Environment Setup

To set up `foundry` environment, run:

```
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

Install dependencies:

```
forge install
```

### Development & Testing

To compile artifacts:

```
forge compile
```

### Additional Documentation & Demos

Refer to `TECH.md` for additional information on implementing reactive contracts and callbacks.

The `src/demos` directory contains several elaborate demos, accompanied by `README.md` files for each one.

### Environment variable configuration for running demos

The following environment variables are used in the instructions for running the demos, and should be configured beforehand.

#### `SEPOLIA_RPC`

The Sepolia Testnet RPC address; `https://rpc2.sepolia.org` unless you want to use your own.

#### `SEPOLIA_PRIVATE_KEY`

The private key to your Sepolia wallet.

#### `REACTIVE_RPC`

For the Reactive Testnet RPC address, refer to the [docs](https://dev.reactive.network/kopli-testnet#kopli-testnet-information).

#### `REACTIVE_PRIVATE_KEY`

The private key to your Reactive wallet.

#### `DEPLOYER_ADDR`

The address of your Reactive wallet.

#### `SYSTEM_CONTRACT_ADDR`

For the system contract address on the Reactive testnet, refer to the [docs](https://dev.reactive.network/kopli-testnet#kopli-testnet-information).

#### `CALLBACK_PROXY_ADDR`

For the callback sender address, refer to the [docs](https://dev.reactive.network/kopli-testnet#kopli-testnet-information).