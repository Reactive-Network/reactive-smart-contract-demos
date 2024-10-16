import os
import json
from dotenv import load_dotenv
from web3 import Web3

# Load environment variables from .env file and set current directory
load_dotenv()
current_dir = os.path.dirname(__file__)

# Constants from .env
INFURA_PROJECT_ID = os.getenv("INFURA_PROJECT_ID")
GENIUS_DEVELOPER_ADDR = os.getenv("GENIUS_DEVELOPER_ADDR")
SECURE_CONTRACT_ADDR = os.getenv("SECURE_CONTRACT_ADDR")
HONEST_ORACLE_ADDR = os.getenv("HONEST_ORACLE_ADDR")
WHATEVER_INSURANCE_PRIVATE_KEY = os.getenv("WHATEVER_INSURANCE_PRIVATE_KEY")

# Connect to SepoliaETH via Infura
web3 = Web3(Web3.HTTPProvider(f'https://sepolia.infura.io/v3/{INFURA_PROJECT_ID}'))

# Check if connected
if not web3.is_connected():
    raise Exception("Failed to connect to SepoliaETH network")
else:
    print("Successfully connected to SepoliaETH network")

# Parse the SecureContract.sol ABI JSON string to a Python dictionary
secure_contract_abi_path = os.path.join(current_dir, '..', '..', '..', 'out', 'SecureContract.sol', 'SecureContract.json')
try:
    with open(secure_contract_abi_path, 'r') as file:
        secure_contract_abi = json.load(file)
except FileNotFoundError:
    print(f"File not found: {secure_contract_abi_path}")
except json.JSONDecodeError:
    print(f"Error decoding JSON from the file: {secure_contract_abi_path}")
except Exception as e:
    print(f"An unexpected error occurred: {e}")

# Parse the HonestOracle.sol ABI JSON string to a Python dictionary
honest_oracle_abi_path = os.path.join(current_dir, '..', '..', '..', 'out', 'HonestOracle.sol', 'HonestOracle.json')
try:
    with open(honest_oracle_abi_path, 'r') as file:
        honest_oracle_abi = json.load(file)
except FileNotFoundError:
    print(f"File not found: {honest_oracle_abi_path}")
except json.JSONDecodeError:
    print(f"Error decoding JSON from the file: {honest_oracle_abi_path}")
except Exception as e:
    print(f"An unexpected error occurred: {e}")

# Initialize contract instances
monitored_contract = web3.eth.contract(address=SECURE_CONTRACT_ADDR, abi=secure_contract_abi['abi'])
oracle_contract = web3.eth.contract(address=HONEST_ORACLE_ADDR, abi=honest_oracle_abi['abi'])

# Get the Whatever Insurance account from private key
account = web3.eth.account.from_key(WHATEVER_INSURANCE_PRIVATE_KEY)
sender_address = account.address

# Function to handle detected transactions
def handle_transaction(event):
    transaction = event['args']
    sender = transaction['initiator']
    amount = transaction['value']
    
    try: # Prepare transaction to emit event via HonestOracle.sol
        txn = oracle_contract.functions.emitEvent(sender, amount).build_transaction({
            'chainId': 11155111, # SepoliaETH chain ID
            'gas': 2000000,
            'gasPrice': web3.eth.gas_price,
            'nonce': web3.eth.get_transaction_count(sender_address),
        })

        # Sign the transaction
        signed_txn = web3.eth.account.sign_transaction(txn, private_key=WHATEVER_INSURANCE_PRIVATE_KEY)

        # Send the transaction
        tx_hash = web3.eth.send_raw_transaction(signed_txn.rawTransaction)
        print(f'Transaction sent with hash: {web3.to_hex(tx_hash)}')
    except Exception as e:
        print(f'Error building or sending transaction: {str(e)}')

# Subscribe to the SecureContract.sol events
def monitor_events():
    event_filter = monitored_contract.events.EthTransferred.create_filter(fromBlock='latest')
    while True:
        for event in event_filter.get_new_entries():
            print(f'\nEvent detected: {event}\n')
            handle_transaction(event)

if __name__ == '__main__':
    print(f"Waiting for SecureContract.sol events...")
    monitor_events()
