Deploy (the constructor argument is the max number of transactions before unsubscribing automatically):

```
forge create --broadcast --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY src/micro-demos/Xfers.sol:Xfers --value 0.1ether --constructor-args 10
```

Export deployed address to `RCT`.

Verify:

```
forge verify-contract --rpc-url https://blockscout-rnk-20-api.prq-infra.net/api/eth-rpc --verifier blockscout --verifier-url 'https://blockscout-rnk-20-api.prq-infra.net/api/' $RCT src/micro-demos/Xfers.sol:Xfers
```

Check the remaining limit of transactions to be processed by using:

```
cast call --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY $RCT "_limit()" 
```

The hash of the last *origin* transaction processed can be found through:

```
cast call --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY $RCT "_lastTxHash()" 
```

The following method returns the block in which the last reactive transaction processed was included:

```
cast call --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY $RCT "_lastReactBlockNumber()" 
```

You can look up your reactive transaction by going to that block in the block exporer (convert to decimal first, e.g. by `cast to-dec`).

Update the transaction limit, and/or add funds by calling the following method:

```
cast send --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY $RCT "updateLimit(uint256)" --value 1ether 20
```

Check the turnover data by calling (the argument is the token address in Sepolia):

```
cast call --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY $RCT "_turnovers(address)" 0x10279e6333f9d0EE103F4715b8aaEA75BE61464C
```

Example traces:

```
cast run --rpc-url $RN_RPC_URL 0xcda3570e0928476b77d0a0aac1764c447cc2af56047076699dd5ce00a767a285
Executing previous transactions from the block.
Traces:
  [85800] 0x8888888888888888888888888888888888888888::trigger(0xa1F3Bc172889B75b5E0331D1ce77eA88c9308ae4, (11155111 [1.115e7], 0x10279e6333f9d0EE103F4715b8aaEA75BE61464C, 100389287136786176327247604509743168900146139575972864366142685224231313322991 [1.003e77], 382152796689287169671614521641338001913773679521 [3.821e47], 840315280240199117554483012236455862957489144475 [8.403e47], 0, 0x00000000000000000000000000000000000000000062b8754897220e3a24ea51, 10896802 [1.089e7], 3, 77138224047990200132079966480880011527414538227973438374748488241763340408897 [7.713e76], 15705506381837338218779224749694884748639094484728842519724017345337319483216 [1.57e76], 10))
    ├─ [80789] 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB::trigger(0xa1F3Bc172889B75b5E0331D1ce77eA88c9308ae4, (11155111 [1.115e7], 0x10279e6333f9d0EE103F4715b8aaEA75BE61464C, 100389287136786176327247604509743168900146139575972864366142685224231313322991 [1.003e77], 382152796689287169671614521641338001913773679521 [3.821e47], 840315280240199117554483012236455862957489144475 [8.403e47], 0, 0x00000000000000000000000000000000000000000062b8754897220e3a24ea51, 10896802 [1.089e7], 3, 77138224047990200132079966480880011527414538227973438374748488241763340408897 [7.713e76], 15705506381837338218779224749694884748639094484728842519724017345337319483216 [1.57e76], 10)) [delegatecall]
    │   ├─ [34421] 0xa1F3Bc172889B75b5E0331D1ce77eA88c9308ae4::react((11155111 [1.115e7], 0x10279e6333f9d0EE103F4715b8aaEA75BE61464C, 100389287136786176327247604509743168900146139575972864366142685224231313322991 [1.003e77], 382152796689287169671614521641338001913773679521 [3.821e47], 840315280240199117554483012236455862957489144475 [8.403e47], 0, 0x00000000000000000000000000000000000000000062b8754897220e3a24ea51, 10896802 [1.089e7], 3, 77138224047990200132079966480880011527414538227973438374748488241763340408897 [7.713e76], 15705506381837338218779224749694884748639094484728842519724017345337319483216 [1.57e76], 10))
    │   │   ├─ emit Turnover(token_: 0x10279e6333f9d0EE103F4715b8aaEA75BE61464C, volume_: 119345809254825234572569169 [1.193e26])
    │   │   └─ ← [Stop]
    │   ├─ [406] 0xa1F3Bc172889B75b5E0331D1ce77eA88c9308ae4::pay(14390400000000000 [1.439e16])
    │   │   └─ ← [Revert] custom error 0x03eb8b54: 00000000000000000000000000000000000000000000000000331ffe182d0000000000000000000000000000000000000000000000000000002677a513c52000
    │   ├─ emit PaymentFailure(contract_: 0xa1F3Bc172889B75b5E0331D1ce77eA88c9308ae4, amount_: 14390400000000000 [1.439e16])
    │   ├─ emit BlacklistContract(reactive_: 0xa1F3Bc172889B75b5E0331D1ce77eA88c9308ae4)
    │   ├─ emit Unkickbackable()
    │   └─ ← [Stop]
    └─ ← [Return]


Transaction successfully executed.
Gas used: 111288
```
