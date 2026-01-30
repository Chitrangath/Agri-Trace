# Deployment Guide for Sepolia Testnet

This guide will walk you through deploying Agri-Trace contracts to Sepolia testnet.

## Prerequisites

1. **Get Sepolia ETH**
   - Use a faucet: https://sepoliafaucet.com/ or https://faucet.quicknode.com/ethereum/sepolia
   - You'll need at least 0.1 ETH for gas fees

2. **Get API Keys**
   - **Infura/Alchemy RPC URL**: Sign up at https://infura.io/ or https://www.alchemy.com/
   - **Etherscan API Key**: Get from https://sepolia.etherscan.io/apis

3. **Install Foundry**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

## Step-by-Step Deployment

### 1. Set Up Environment Variables

Create a `.env` file in the project root:

```bash
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
SEPOLIA_ETHERSCAN_API_KEY=your_etherscan_api_key
```

**⚠️ Security Warning**: Never commit your `.env` file. It's already in `.gitignore`.

### 2. Install Dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

### 3. Build Contracts

```bash
forge build
```

This should compile all contracts successfully. If you see errors, check that dependencies are installed correctly.

### 4. Run Tests (Optional but Recommended)

```bash
forge test
```

All tests should pass before deployment.

### 5. Deploy to Sepolia

Run the deployment script:

```bash
forge script script/DeploySepolia.s.sol:DeploySepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**What this does:**
- `--rpc-url`: Uses your Sepolia RPC endpoint
- `--broadcast`: Actually sends transactions (remove for dry-run)
- `--verify`: Automatically verifies contracts on Etherscan
- `-vvvv`: Verbose output for debugging

### 6. Verify Deployment

After deployment, you'll see output like:

```
=== DEPLOYMENT SUMMARY ===
Network: Sepolia Testnet
 AgricultureSupplyChain: 0x...
 PaymentContract: 0x...
 QRCodeRegistry: 0x...
 FairPricingContract: 0x...
 ConsumerInterface: 0x...
 FraudDetectionContract: 0x...
```

Contract addresses are also saved to `deployments/sepolia-contracts.env`.

### 7. Verify on Etherscan

Visit https://sepolia.etherscan.io/ and search for your contract addresses. They should be verified automatically if you used `--verify`.

If verification failed, manually verify:

```bash
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> \
  --chain sepolia \
  --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" <arg1> <arg2> <arg3>)
```

## Post-Deployment Setup

### 1. Register Additional Farmers

```solidity
// On Etherscan or via script
supplyChain.grantFarmerRole(0xFarmerAddress);
fairPricing.registerFarmer(0xFarmerAddress);
```

### 2. Configure Price Oracle

```solidity
fairPricing.grantRole(PRICE_ORACLE_ROLE, 0xOracleAddress);
```

### 3. Set Up Fraud Analysts

```solidity
fraudDetection.grantRole(FRAUD_ANALYST_ROLE, 0xAnalystAddress);
```

## Troubleshooting

### Error: "insufficient funds"
- Get more Sepolia ETH from a faucet
- Check your account balance: `cast balance <your_address> --rpc-url $SEPOLIA_RPC_URL`

### Error: "nonce too high"
- Your local nonce is out of sync. Reset it or wait a bit.

### Error: "contract verification failed"
- Check your Etherscan API key
- Try manual verification on Etherscan
- Ensure constructor arguments are correct

### Error: "missing dependencies"
- Run `forge install OpenZeppelin/openzeppelin-contracts`
- Check `remappings.txt` exists and is correct

## Gas Estimates

Approximate gas costs for deployment (as of 2024):
- AgricultureSupplyChain: ~2,500,000 gas
- PaymentContract: ~1,800,000 gas
- QRCodeRegistry: ~1,200,000 gas
- FairPricingContract: ~2,800,000 gas
- ConsumerInterface: ~1,500,000 gas
- FraudDetectionContract: ~3,200,000 gas

**Total**: ~13,000,000 gas ≈ 0.01-0.02 ETH (depending on gas price)

## Next Steps

1. Test all contract functions on Sepolia
2. Create a frontend to interact with contracts
3. Set up monitoring and alerts
4. Plan for mainnet deployment (after audit)

## Support

If you encounter issues:
1. Check the [README.md](./README.md) for general information
2. Review contract code in `src/`
3. Check test files in `test/` for usage examples
4. Open an issue on GitHub

---

**Remember**: This is testnet deployment. Always test thoroughly before considering mainnet!
