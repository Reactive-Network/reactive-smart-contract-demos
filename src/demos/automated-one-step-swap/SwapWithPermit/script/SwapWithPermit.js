const path = require('path');
const dotenv = require('dotenv');
const ethers = require('ethers');


async function main() {
  load_env_variables();

  // Connect to the network
  const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC);
  const signer = new ethers.Wallet(process.env.SEPOLIA_PRIVATE_KEY, provider);
  const chainId = (await provider.getNetwork()).chainId;

  // Create contract instances
  const originContract = new ethers.Contract(process.env.ORIGIN_WITH_PERMIT_CONTRACT_ADDRESS, CONTRACT_ABI, signer);
  const tokenInContract = new ethers.Contract(process.env.TOKEN_IN_WITH_PERMIT_ADDRESS, TOKEN_ABI, provider);

  // Prepare parameters
  const ownerAddress = await signer.getAddress();
  const amountIn = process.env.AMOUNT_IN_WITH_PERMIT;
  const amountOutMin = process.env.AMOUNT_OUT_MIN;
  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
  const tokenName = await tokenInContract.name();
  const nonce = await tokenInContract.nonces(ownerAddress);

  console.log('Generating permit signature...');
  const sig = await generatePermitSignature({
    tokenAddress: process.env.TOKEN_IN_WITH_PERMIT_ADDRESS,
    ownerAddress,
    spenderAddress: process.env.ORIGIN_WITH_PERMIT_CONTRACT_ADDRESS,
    value: amountIn,
    deadline,
    nonce,
    chainId,
    signer,
    tokenName
  });
  console.log('Permit signature generated.');

  console.log('Calling Origin Contract...');
  const tx = await callApproveSwapWithPermit({
    contract: originContract,
    tokenIn: process.env.TOKEN_IN_WITH_PERMIT_ADDRESS,
    tokenOut: process.env.TOKEN_OUT_WITH_PERMIT_ADDRESS,
    amountIn,
    amountOutMin,
    fee: parseInt(process.env.FEE),
    deadline,
    v: sig.v,
    r: sig.r,
    s: sig.s
  });

  console.log(`Transaction sent: ${tx.hash}`);
  console.log('Waiting for confirmation...');

  const receipt = await tx.wait();
  console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
}

/**
 * Load environment variables from the .env file in the root directory
 */
function load_env_variables() {
  const envPath = path.resolve(process.cwd(), '..', '..', '..', '..', '.env');
  const result = dotenv.config({ path: envPath });
  if (result.error) {
    throw result.error;
  }
  console.log('Loaded .env file from:', envPath);
}

/**
 * Generates the permit signature for EIP-2612.
 * @returns {Promise<{v: number, r: string, s: string}>} The signature components.
 */
async function generatePermitSignature({
  tokenAddress,
  ownerAddress,
  spenderAddress,
  value,
  deadline,
  nonce,
  chainId,
  signer,
  tokenName
}) {
  const domain = {
    name: tokenName,
    version: '1',
    chainId: chainId,
    verifyingContract: tokenAddress
  };

  const types = {
    Permit: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' }
    ]
  };

  const message = {
    owner: ownerAddress,
    spender: spenderAddress,
    value: value,
    nonce: nonce,
    deadline: deadline
  };

  const signature = await signer.signTypedData(domain, types, message);
  return ethers.Signature.from(signature);
}

/**
 * Calls the approveSwapWithPermit function on the contract.
 * @returns {Promise<ethers.ContractTransaction>} The transaction object.
 */
async function callApproveSwapWithPermit({
  contract,
  tokenIn,
  tokenOut,
  amountIn,
  amountOutMin,
  fee,
  deadline,
  v,
  r,
  s
}) {
  return contract.approveSwapWithPermit(
    tokenIn,
    tokenOut,
    amountIn,
    amountOutMin,
    fee,
    deadline,
    v,
    r,
    s
  );
}

// ABI for the approveSwapWithPermit function
const CONTRACT_ABI = [
  {
    "inputs": [
      {"name": "tokenIn", "type": "address"},
      {"name": "tokenOut", "type": "address"},
      {"name": "amountIn", "type": "uint256"},
      {"name": "amountOutMin", "type": "uint256"},
      {"name": "fee", "type": "uint24"},
      {"name": "deadline", "type": "uint256"},
      {"name": "v", "type": "uint8"},
      {"name": "r", "type": "bytes32"},
      {"name": "s", "type": "bytes32"}
    ],
    "name": "approveSwapWithPermit",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

// Token ABI for nonces, name, decimals, and balanceOf functions
const TOKEN_ABI = [
  {
    "inputs": [{"name": "owner", "type": "address"}],
    "name": "nonces",
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "name",
    "outputs": [{"name": "", "type": "string"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [{"name": "", "type": "uint8"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "account", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  }
];


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('An error occurred:', error);
    process.exit(1);
  });
