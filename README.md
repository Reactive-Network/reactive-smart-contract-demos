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

The following environment variables are used in the instructions for running the demos, and should be configured ahead of time.

#### `SEPOLIA_RPC`

RPC address for Sepolia testnet, `https://rpc2.sepolia.org` unless you want to use your own.

#### `SEPOLIA_PRIVATE_KEY`

Private key to your Sepolia wallet.

#### `REACTIVE_RPC`

RPC address for Reactive testnet, should be set to `https://kopli-rpc.reactive.network/`.

#### `REACTIVE_PRIVATE_KEY`

Private key to your Reactive wallet.

#### `DEPLOYER_ADDR`

The address of your Reactive wallet.

#### `SYSTEM_CONTRACT_ADDR`

System contract address for Reactive testnet, should be set to `0x0000000000000000000000000000000000FFFFFF`.

#### `CALLBACK_SENDER_ADDR`

Refer to the documentation for addresses used by Reactive testnet for callbacks on supported networks.

