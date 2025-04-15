```bash
forge create --rpc-url https://mainnet.base.org --private-key $HL_PK src/demos/hyperlane/HyperlaneOrigin.sol:HyperlaneOrigin --constructor-args 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D

export HL_ORIGIN_ADDR=0xF37652D7aF808287DEB26dDcb400352d8BA012Ef

forge create --legacy --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HL_PK src/demos/hyperlane/HyperlaneReactive.sol:HyperlaneReactive --value 0.2ether --constructor-args 0x3a464f746D23Ab22155710f44dB16dcA53e0775E 8453 $HL_ORIGIN_ADDR

export HL_REACTIVE_ADDR=0xF37652D7aF808287DEB26dDcb400352d8BA012Ef

cast send --legacy --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HL_PK $HL_REACTIVE_ADDR "send(bytes)" 0xabcdef

cast send --legacy --rpc-url https://mainnet-rpc.rnk.dev/ --private-key $HL_PK $HL_REACTIVE_ADDR "trigger(bytes)" 0xfedcba

cast send --rpc-url https://mainnet.base.org --private-key $HL_PK $HL_ORIGIN_ADDR "trigger(bytes)" 0xdefabc
```
