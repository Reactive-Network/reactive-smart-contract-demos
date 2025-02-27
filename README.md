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

The `src/demos` directory contains several demos with their `README.md` files.

### Environment Variable Configuration

The following environment variables are used in the instructions for running the demos, and should be configured beforehand.

#### `ORIGIN/DESTINATION_RPC`

RPC URL for the origin/destination chain (see [Chainlist](https://chainlist.org)).

#### `ORIGIN/DESTINATION_PRIVATE_KEY`

Private key for signing transactions on the origin/destination chain.

#### `REACTIVE_RPC`

RPC URL for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet)).

#### `REACTIVE_PRIVATE_KEY`

Private key for signing transactions on the Reactive Network.

#### `SYSTEM_CONTRACT_ADDR`

The service address for the Reactive Network (see [Reactive Docs](https://dev.reactive.network/reactive-mainnet#overview)).

#### `CALLBACK_PROXY_ADDR`

The address that verifies callback authenticity (see [Reactive Docs](https://dev.reactive.network/origins-and-destinations#callback-proxy-address)).
