#!/bin/bash
set -e

# ============================================================
# STEP 0: Load environment
# ============================================================
source .env

echo "=========================================="
echo "  LEVERAGE LOOP - MANUAL TESTING SCRIPT"
echo "=========================================="

# ============================================================
# STEP 1: Build contracts
# ============================================================
echo ""
echo "[STEP 1] Building contracts..."
forge build

# ============================================================
# STEP 2: Deploy LeverageAccount on Sepolia
# ============================================================
echo ""
echo "[STEP 2] Deploying LeverageAccount on Sepolia..."

LEV_DEPLOY_OUTPUT=$(forge create \
  --rpc-url $DESTINATION_RPC \
  --private-key $DESTINATION_PRIVATE_KEY \
  src/demos/leverage-loop/LeverageAccount.sol:LeverageAccount \
  --constructor-args $POOL_ADDR $ROUTER_ADDR $DESTINATION_CALLBACK_PROXY_ADDR $CLIENT_WALLET)

echo "$LEV_DEPLOY_OUTPUT"

LEV_ACCOUNT_ADDR=$(echo "$LEV_DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
echo ""
echo ">>> LeverageAccount deployed at: $LEV_ACCOUNT_ADDR"

# ============================================================
# STEP 3: Deploy LoopingRSC on Reactive Network
# ============================================================
echo ""
echo "[STEP 3] Deploying LoopingRSC on Reactive Network..."

RSC_DEPLOY_OUTPUT=$(forge create \
  --rpc-url $REACTIVE_RPC \
  --private-key $REACTIVE_PRIVATE_KEY \
  src/demos/leverage-loop/LoopingRSC.sol:LoopingRSC \
  --constructor-args $SYSTEM_CONTRACT_ADDR $LEV_ACCOUNT_ADDR $WETH_ADDR $BORROW_ASSET_ADDR $BORROW_ASSET_DECIMALS)

echo "$RSC_DEPLOY_OUTPUT"

RSC_ADDR=$(echo "$RSC_DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
echo ""
echo ">>> LoopingRSC deployed at: $RSC_ADDR"

# ============================================================
# STEP 4: Authorize RSC on LeverageAccount
# ============================================================
echo ""
echo "[STEP 4] Authorizing RSC caller on LeverageAccount..."

cast send $LEV_ACCOUNT_ADDR \
  "setRSCCaller(address)" $RSC_ADDR \
  --rpc-url $DESTINATION_RPC \
  --private-key $DESTINATION_PRIVATE_KEY

echo ">>> RSC authorized."

# Verify
echo ""
echo "[VERIFY] Checking rscCaller..."
cast call $LEV_ACCOUNT_ADDR "rscCaller()(address)" --rpc-url $DESTINATION_RPC

# ============================================================
# STEP 5: Set Chainlink Oracles
# ============================================================
echo ""
echo "[STEP 5] Setting Chainlink oracles..."

# WETH/USD oracle
cast send $LEV_ACCOUNT_ADDR \
  "setOracle(address,address)" $WETH_ADDR $WETH_USD_ORACLE \
  --rpc-url $DESTINATION_RPC \
  --private-key $DESTINATION_PRIVATE_KEY

echo ">>> WETH oracle set."

# USDC/USD oracle
cast send $LEV_ACCOUNT_ADDR \
  "setOracle(address,address)" $BORROW_ASSET_ADDR $USDC_USD_ORACLE \
  --rpc-url $DESTINATION_RPC \
  --private-key $DESTINATION_PRIVATE_KEY

echo ">>> USDC oracle set."

# Verify oracles work
echo ""
echo "[VERIFY] WETH price (18 decimals):"
cast call $LEV_ACCOUNT_ADDR "getAssetPrice(address)(uint256)" $WETH_ADDR --rpc-url $DESTINATION_RPC

echo "[VERIFY] USDC price (18 decimals):"
cast call $LEV_ACCOUNT_ADDR "getAssetPrice(address)(uint256)" $BORROW_ASSET_ADDR --rpc-url $DESTINATION_RPC

# ============================================================
# STEP 6: Check WETH balance & wrap ETH if needed
# ============================================================
echo ""
echo "[STEP 6] Checking WETH balance..."

WETH_BALANCE=$(cast call $WETH_ADDR "balanceOf(address)(uint256)" $CLIENT_WALLET --rpc-url $DESTINATION_RPC)
echo "Current WETH balance: $WETH_BALANCE"

echo ""
echo "If you need WETH, run this manually to wrap 0.01 ETH:"
echo "  cast send $WETH_ADDR \"deposit()\" --value 0.01ether --rpc-url \$DESTINATION_RPC --private-key \$DESTINATION_PRIVATE_KEY"
echo ""
read -p "Press ENTER once you have enough WETH to continue..."

# ============================================================
# STEP 7: Approve WETH spending
# ============================================================
DEPOSIT_AMOUNT=10000000000000000  # 0.01 WETH (10^16 wei)

echo ""
echo "[STEP 7] Approving $DEPOSIT_AMOUNT WETH for LeverageAccount..."

cast send $WETH_ADDR \
  "approve(address,uint256)" $LEV_ACCOUNT_ADDR $DEPOSIT_AMOUNT \
  --rpc-url $DESTINATION_RPC \
  --private-key $DESTINATION_PRIVATE_KEY

echo ">>> Approval done."

# Verify allowance
echo "[VERIFY] Allowance:"
cast call $WETH_ADDR "allowance(address,address)(uint256)" $CLIENT_WALLET $LEV_ACCOUNT_ADDR --rpc-url $DESTINATION_RPC

# ============================================================
# STEP 8: Deposit WETH — triggers the leverage loop!
# ============================================================
echo ""
echo "[STEP 8] Depositing WETH into LeverageAccount..."
echo ">>> This emits Deposited event -> Reactive Network picks it up -> Loop begins!"

cast send $LEV_ACCOUNT_ADDR \
  "deposit(address,uint256)" $WETH_ADDR $DEPOSIT_AMOUNT \
  --rpc-url $DESTINATION_RPC \
  --private-key $DESTINATION_PRIVATE_KEY

echo ">>> Deposit done! Leverage loop should start automatically."

# ============================================================
# STEP 9: Monitor position
# ============================================================
echo ""
echo "[STEP 9] Checking initial position status..."

cast call $LEV_ACCOUNT_ADDR "getStatus()(uint256,uint256,uint256,uint256,uint256,uint256)" --rpc-url $DESTINATION_RPC

echo ""
echo "=========================================="
echo "  MONITORING COMMANDS (run these manually)"
echo "=========================================="
echo ""
echo "# Check position status (totalCollateral, totalDebt, availableBorrows, liqThreshold, ltv, healthFactor):"
echo "cast call $LEV_ACCOUNT_ADDR \"getStatus()(uint256,uint256,uint256,uint256,uint256,uint256)\" --rpc-url \$DESTINATION_RPC"
echo ""
echo "# Watch for LoopStepExecuted events:"
echo "cast logs --from-block latest --address $LEV_ACCOUNT_ADDR --rpc-url \$DESTINATION_RPC"
echo ""
echo "=========================================="
echo "  DONE! Wait ~30-60s for Reactive Network"
echo "  to detect events and execute callbacks."
echo "=========================================="
