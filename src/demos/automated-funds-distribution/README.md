# Automated Funds Distribution

## Overview

This demo implements an automated funds distribution system using smart contracts. It showcases the following key functionalities:

- **Multi-Party Wallet:** A contract that allows multiple users to contribute funds and become shareholders.
- **Automated Distribution:** Utilizes a reactive contract to automatically distribute funds and tokens to shareholders.
- **Dynamic Share Calculation:** Recalculates shares when shareholders leave or new funds are added.

## Contracts

The demo involves three main contracts:

1. **MemeCoin Contract:** An ERC-20 token contract that represents the BananaCoin (BobBanana) used in the system.

2. **MultiPartyWallet Contract:** Manages contributions, shareholding, and fund distribution.

3. **MultiPartyWalletReactive Contract:** Listens for events from the MultiPartyWallet contract and triggers automated actions.

## Further Considerations

The demo showcases basic automated distribution functionality but can be improved with:

- **Enhanced Security Measures:** Implementing additional checks and balances for fund management.
- **More Flexible Distribution Rules:** Allowing for customizable distribution schemes.
- **Integration with DeFi Protocols:** Exploring yield-generating opportunities for idle funds.
- **Improved Gas Optimization:** Refining the contract logic to reduce transaction costs.

## Deployment & Testing

To deploy and test the contracts, follow these steps. Ensure the following environment variables are configured appropriately:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`


You can use the recommended Sepolia RPC URL: `https://rpc2.sepolia.org`.

### Step 1: Deploy MemeCoin contract on Sepolia

Deploy the MemeCoin contract with an initial supply of 1,000,000 BananaCoin (BobBanana):

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/automated-funds-distribution/MemeCoin.sol:MemeCoin --constructor-args 1000000000000000000000000
```

### Step 2: Deploy MultiPartyWallet contract on Sepolia

Deploy the MultiPartyWallet contract:

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/automated-funds-distribution/MultiPartyWallet.sol:MultiPartyWallet
```

### Step 3: Deploy MultiPartyWalletReactive contract on Reactive Network

Deploy the MultiPartyWalletReactive contract, passing in the MultiPartyWallet address:

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/demos/automated-funds-distribution/MultiPratyWalletReactive.sol:MultiPratyWalletReactive --constructor-args $MULTIPARTYWALLET_ADDRESS
```

### Step 4: Initialize the wallet

Set up the wallet with the following parameters:
- Minimum contribution: 0.01 ETH
- Closure time: 15 minutes from now
- MemeCoin address: [MEMECOIN_ADDRESS]
- MemeCoinsPerEth: 1000 (1 ETH = 1000 BananaCoin)

```bash
cast send $MULTIPARTYWALLET_ADDRESS "initialize(uint256,uint256,address,uint256)" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY [MIN_CONTRIBUTION] [CLOSURE_TIME] [MEMECOIN_ADDRESS] 1000
```

### Step 5: Contribute to the wallet

Multiple users can contribute ETH to become shareholders (minimum contribution: 0.1 ETH):

```bash
cast send $MULTIPARTYWALLET_ADDRESS --value 0.1ether --rpc-url $SEPOLIA_RPC --private-key $USER_PRIVATE_KEY
```

### Step 6: Close the wallet

After the closure time, call the closeWallet function:

```bash
cast send $MULTIPARTYWALLET_ADDRESS "closeWallet()" --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

### Step 7: Distribute additional funds

Send additional funds to the wallet using the receive function:

```bash
cast send $MULTIPARTYWALLET_ADDRESS --value 1ether --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

### Step 8: Shareholder leaves

A shareholder can leave by calling the leaveShareholding function:

```bash
cast send $MULTIPARTYWALLET_ADDRESS "leaveShareholding()" --rpc-url $SEPOLIA_RPC --private-key $SHAREHOLDER_PRIVATE_KEY
```

The MultiPartyWalletReactive contract will automatically detect events from the MultiPartyWallet contract and trigger appropriate actions, such as updating shares and distributing funds.