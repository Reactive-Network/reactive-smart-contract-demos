# Reactive Smart Contract Demos

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

To run the test suite:

```
forge test -vv
```

To inspect the call tree:

```
forge test -vvvv
```

### Additional Documentation & Demos

Refer to [Docs](https://dev.reactive.network/system-contract) or [TECH.md](https://github.com/Reactive-Network/reactive-smart-contract-demos/blob/main/TECH.md) for additional information on implementing reactive contracts and callbacks. The `src/demos` directory contains several demos with their `README.md` files.

### Environment Variable Configuration

The following environment variables are used in the instructions for running the demos, and should be configured beforehand.

#### `SEPOLIA_RPC`

Ethereum Sepolia RPC address — `https://rpc2.sepolia.org`.

#### `SEPOLIA_PRIVATE_KEY`

Ethereum Sepolia private key.

#### `REACTIVE_RPC`

Kopli Testnet RPC address — `https://kopli-rpc.rkt.ink`.

#### `REACTIVE_PRIVATE_KEY`

Kopli Testnet private key.

#### `SYSTEM_CONTRACT_ADDR`

The system contract address on [Kopli Testnet](https://dev.reactive.network/kopli-testnet#kopli-testnet-information)

#### `CALLBACK_PROXY_ADDR`

For callback proxy addresses, refer to the [docs](https://dev.reactive.network/origins-and-destinations#chains).
