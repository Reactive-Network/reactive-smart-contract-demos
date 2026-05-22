Deploy:

```
forge create --broadcast --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY src/micro-demos/PingPong.sol:PingPong --value 0.1ether
```

Export deployed address to `RCT`.

Verify:

```
forge verify-contract --rpc-url https://blockscout-rnk-20-api.prq-infra.net/api/eth-rpc --verifier blockscout --verifier-url 'https://blockscout-rnk-20-api.prq-infra.net/api/' $RCT src/micro-demos/PingPong.sol:PingPong
```

Generate the test event, this should trigger the reactive transaction:

```
cast send --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY $RCT "ping()" 
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

Example traces:

```
cast run --rpc-url $RN_RPC_URL 0xe9c7cb039f31b6ddb37020ddf3048f3b25285c1f81d4e1a05922690ed2ab9a88
Executing previous transactions from the block.
Traces:
  [109979] 0x8888888888888888888888888888888888888888::trigger(0x388b95B9f4d6ef257E1114b355B592C668f64fA1, (5318007 [5.318e6], 0x388b95B9f4d6ef257E1114b355B592C668f64fA1, 91562447057405671640282945446290641806549385168621581491857088437350338627247 [9.156e76], 0, 0, 0, 0x, 3104028 [3.104e6], 1, 19822760739557217501677614512494790916663515155793649151063107435485242088668 [1.982e76], 32361637826153728953520752153828595736060196332559319908312165082284906809902 [3.236e76], 1))
    ├─ [104974] 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB::trigger(0x388b95B9f4d6ef257E1114b355B592C668f64fA1, (5318007 [5.318e6], 0x388b95B9f4d6ef257E1114b355B592C668f64fA1, 91562447057405671640282945446290641806549385168621581491857088437350338627247 [9.156e76], 0, 0, 0, 0x, 3104028 [3.104e6], 1, 19822760739557217501677614512494790916663515155793649151063107435485242088668 [1.982e76], 32361637826153728953520752153828595736060196332559319908312165082284906809902 [3.236e76], 1)) [delegatecall]
    │   ├─ [46357] 0x388b95B9f4d6ef257E1114b355B592C668f64fA1::react((5318007 [5.318e6], 0x388b95B9f4d6ef257E1114b355B592C668f64fA1, 91562447057405671640282945446290641806549385168621581491857088437350338627247 [9.156e76], 0, 0, 0, 0x, 3104028 [3.104e6], 1, 19822760739557217501677614512494790916663515155793649151063107435485242088668 [1.982e76], 32361637826153728953520752153828595736060196332559319908312165082284906809902 [3.236e76], 1))
    │   │   ├─ emit Pong(txHash_: 32361637826153728953520752153828595736060196332559319908312165082284906809902 [3.236e76])
    │   │   └─ ← [Stop]
    │   ├─ [9135] 0x388b95B9f4d6ef257E1114b355B592C668f64fA1::pay(15583400000000000 [1.558e16])
    │   │   ├─ [1765] 0x8888888888888888888888888888888888888888::fallback{value: 15583400000000000}()
    │   │   │   ├─ [1347] 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB::fallback{value: 15583400000000000}() [delegatecall]
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   └─ ← [Stop]
    │   ├─ [0] 0x038E06667e42782E571EaB20432b9237F9bD6B82::fallback{value: 15583400000000000}()
    │   │   └─ ← [Stop]
    │   └─ ← [Stop]
    └─ ← [Return]


Transaction successfully executed.
Gas used: 114815
```
