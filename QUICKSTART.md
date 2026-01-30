# Quick Start Guide - Sepolia Deployment

## 🚀 Fast Deployment (5 minutes)

### 1. Prerequisites Check
```bash
# Check Foundry is installed
forge --version

# Check you have Sepolia ETH
# Get from: https://sepoliafaucet.com/
```

### 2. Setup Environment
```bash
# Create .env file
cat > .env << EOF
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
SEPOLIA_ETHERSCAN_API_KEY=your_etherscan_key
EOF
```

### 3. Install & Build
```bash
# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts

# Build contracts
forge build
```

### 4. Deploy
```bash
# Deploy to Sepolia
forge script script/DeploySepolia.s.sol:DeploySepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### 5. Verify
Check `deployments/sepolia-contracts.env` for addresses, then visit:
- https://sepolia.etherscan.io/

## 📋 Common Commands

```bash
# Run tests
forge test

# Build only
forge build

# Test specific contract
forge test --match-contract AgricultureSupplyChainTest

# Deploy without verification (faster)
forge script script/DeploySepolia.s.sol:DeploySepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast

# Check balance
cast balance <your_address> --rpc-url $SEPOLIA_RPC_URL
```

## 🐛 Troubleshooting

**"Missing dependencies"**
```bash
forge install OpenZeppelin/openzeppelin-contracts
```

**"Insufficient funds"**
- Get Sepolia ETH: https://sepoliafaucet.com/

**"Verification failed"**
- Check API key is correct
- Try manual verification on Etherscan

## 📚 Next Steps

1. Read [README.md](./README.md) for full documentation
2. Check [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed guide
3. Review contract code in `src/`
4. Test on Sepolia before mainnet

---

**Need help?** Check the full [README.md](./README.md) or [DEPLOYMENT.md](./DEPLOYMENT.md)
