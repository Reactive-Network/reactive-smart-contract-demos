Certainly! I'll convert your README into a format similar to the examples you provided. Here's a restructured version of your README:

# Automated One-Step Swap with IERC20 Permit

## Overview

This demo showcases an automated one-step swap using the IERC20 Permit functionality. It differs from the implementation in the `/automated-one-step-swap` directory, swapping USDT for WETH9 instead of the reverse.

Key functionalities:
- Off-chain signature generation for permit
- Low-latency monitoring of approval events
- Automated execution of Uniswap V3 swaps

```mermaid
flowchart TD
    User([User Initiates Swap Script])
    Signature[Generate Off-Chain Signature]
    OriginContract[Origin Contract - Approves and Emits Event]
    ReactiveContract[Reactive Contract - Detects Event and Calls Callback]
    UniswapSwap[Execute Swap on Uniswap]

    User --> Signature
    Signature --> OriginContract
    OriginContract --> ReactiveContract
    ReactiveContract --> UniswapSwap

```

## Contracts

The demo involves two main contracts:

1. **Origin Chain Contract (`OriginWithPermitContract.sol`):** Deployed on Sepolia, this contract approves itself as the spender, transfers tokens from the user, and emits an `Approval` event. It then awaits the RSC to trigger the `callback()` function.

2. **Reactive Chain Contract (`ReactiveWithPermitContract.sol`):** Deployed on the Reactive chain, this contract listens for the `Approval` event from the Origin contract and calls the `callback()` function on the Origin contract to execute the swap.

## Further Considerations

Potential improvements include:
- Multi-token support
- Dynamic fee adjustment
- Integration with other DEXes
- Advanced slippage protection

## Deployment & Testing

To deploy and test the contracts, follow these steps. Ensure the following environment variables are configured in your `.env` file:

* `SEPOLIA_RPC` — https://rpc2.sepolia.org
* `SEPOLIA_PRIVATE_KEY` — Ethereum Sepolia private key
* `REACTIVE_RPC` — https://kopli-rpc.rkt.ink
* `REACTIVE_PRIVATE_KEY` — Reactive Kopli private key
* `SEPOLIA_CALLBACK_PROXY_ADDR` — 0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8
* `KOPLI_CALLBACK_PROXY_ADDR` — 0x0000000000000000000000000000000000FFFFFF
* `TOKEN_IN_ADDRESS` — 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14(Weth9-here for demonstration purpose can be changed as per requirement)
* `TOKEN_OUT_ADDRESS` —0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0(USDT-here for demonstration purpose can be changed as per requirement)

### Step 1: Set up environment

```bash
cd src/demos/automated-one-step-swap/SwapWithPermit/
npm install dotenv ethers
```

### Step 2: Deploy Origin Contract

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/automated-one-step-swap/SwapWithPermit/src/PermitContract.sol:PermitContract --constructor-args 0x0000000000000000000000000000000000000000
```

Assign the deployment address to `ORIGIN_WITH_PERMIT_CONTRACT_ADDRESS` in your `.env` file.


#### Callback Payment

To ensure a successful callback, the callback contract must have an ETH balance. You can find more details [here](https://dev.reactive.network/system-contract#callback-payments). To fund the callback contract, run the following command:

```bash
cast send $CALLBACK_ADDR --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY --value 0.1ether
```

Alternatively, you can deposit the funds into the callback proxy smart contract using this command:

```bash
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $CALLBACK_PROXY_ADDR "depositTo(address)" $CALLBACK_ADDR --value 0.1ether
```


### Step 3: Deploy Reactive Contract

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/automated-one-step-swap/SwapWithPermit/src/ReactiveWithPermitContract.sol:ReactiveWithPermitContract --constructor-args $ORIGIN_WITH_PERMIT_CONTRACT_ADDRESS
```


### Step 4: Test the Setup

```bash
cd src/demos/automated-one-step-swap/SwapWithPermit/script
node SwapWithPermit.js
```

This script will generate off-chain signatures and initiate the swap process.

"To acquire tokens refer to `Readme.md` file of WithoutPermit"

## Troubleshooting

- Ensure Ethers.js is version 6.0.0 or higher
- Use appropriate parsing for large numbers in `AMOUNT_IN`
- Ensure sufficient SepoliaETH and REACT for gas fees
- Verify WETH9 balance in your Sepolia wallet
- Double-check environment variable loading with `source .env`
- Monitor events on Sepolia Etherscan for debugging
- Be cautious with token decimal places (USDT: 6, WETH9: 18)
- Remember `TOKEN_IN_WITH_PERMIT_ADDRESS` is the token you want to sell
- Note that WETH9 does not implement IERC20 Permit
