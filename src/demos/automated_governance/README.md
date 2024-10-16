# Automated Governance Contract

## Overview

The Automated Governance Contract is a decentralized governance system that enables users to create proposals, vote on them, and execute or reject them based on voting outcomes. This system facilitates community-driven decision-making in a transparent and efficient manner across two blockchain networks.

### Key Features:

1. **Proposal Creation:** Users can create proposals with descriptions.
2. **Voting:** Users can vote for or against proposals.
3. **Automatic Execution:** Proposals are automatically executed or deleted based on voting outcomes and deadlines.
4. **Cross-Chain Communication:** Utilizes a reactive contract to monitor and respond to events on the origin chain.
5. **Event Emission:** Emits various events to track proposal lifecycle and voting activities.

## Workflow

```mermaid
%%{ init: {'flowchart': { 'curve':'basis'}}}%%
flowchart LR
    User([User])
    subgraph GC[Governance Contract]
        CreateProposal[createProposal]
        Vote[vote]
        Execute[executeProposal]
        CheckDeadlines[checkProposalDeadlines]
    end
    subgraph RC[Reactive Contract]
        ListenEvents[Listen for Events]
        TriggerActions[Trigger Actions]
    end

    User -->|1. Creates proposal| CreateProposal
    User -->|2. Votes on proposal| Vote
    CheckDeadlines -->|3. Checks deadlines| GC
    GC -->|4. Emits events| RC
    RC -->|5. Executes or deletes proposals| Execute
```

## Contracts

The demo involves two main contracts:

1. **Origin Chain Contract:** `Governance` manages proposals, voting, and execution processes on the primary chain (Sepolia).

2. **Reactive Contract:** `ReGovReactive` listens for events from the Governance contract and triggers appropriate actions on the Reactive Network.

## Further Considerations

While this demo showcases basic automated governance, potential improvements include:

- **Enhanced Voting Mechanisms:** Implement weighted voting or quadratic voting.
- **Proposal Queuing:** Add a timelock feature for executed proposals.
- **Delegation:** Allow users to delegate their voting power.
- **Multi-chain Governance:** Extend the system to govern multiple chains simultaneously.

## Deployment & Testing

To deploy and test the contracts, follow these steps. Ensure the following environment variables are configured appropriately:

* `SEPOLIA_RPC`
* `SEPOLIA_PRIVATE_KEY`
* `REACTIVE_RPC`
* `REACTIVE_PRIVATE_KEY`


You can use the recommended Sepolia RPC URL: `https://rpc2.sepolia.org`.

### Step 1: Deploy Governance contract on Sepolia

Deploy the Governance contract:

```sh
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/Autonomated_Governance/Governance.sol:Governance
```

Save the returned address in `O_ORIGIN_ADDR`.

### Step 2: Deploy ReGovReactive contract on Reactive Network

Deploy the ReGovReactive contract, passing in the Subscription Service address and the Governance contract address:

```sh
forge create --rpc-url $REACTIVE_RPC --private-key $REACTIVE_PRIVATE_KEY src/Autonomated_Governance/ReGovReactive.sol:ReGovReactive --constructor-args $SYSTEM_CONTRACT_ADDR $O_ORIGIN_ADDR
```

### Step 3: Create a proposal

Call the createProposal function on the Governance contract:

```sh
cast send $O_ORIGIN_ADDR "createProposal(string memory)" task1 --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

This creates a new proposal with a 5-minute deadline.

### Step 4: Vote on the proposal

Multiple users call the vote function to vote on the proposal:

```sh
cast send $O_ORIGIN_ADDR "vote(uint256,bool)" 1 true --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY
```

### Step 5: Proposal Resolution

The proposal will be automatically resolved based on voting outcomes:

- If the "For" threshold is reached, the Reactive contract will execute the proposal.
- If the "Against" threshold is reached, the Reactive contract will delete the proposal.
- If the deadline is reached without meeting either threshold, the Reactive contract will execute the proposal.

The system will automatically handle these actions based on the emitted events from the Governance contract.