Possible constructor arguments: `1`, `10`, `100`, `1000`, `10000`.

```bash
forge create --broadcast --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY src/micro-demos/Cron.sol:CronDemo --value 1ether --constructor-args 10
```

To pause the contract:

```bash
cast send $CONTRACT_ADDR "pause()" --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY
```

To resume the contract:

```bash
cast send $CONTRACT_ADDR "resume()" --rpc-url $RN_RPC_URL --private-key $REACTIVE_PRIVATE_KEY
```