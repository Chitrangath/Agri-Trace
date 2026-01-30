# Agri-Trace: Blockchain-Based Agricultural Supply Chain Traceability

A comprehensive smart contract system for tracking agricultural products from farm to consumer, ensuring transparency, fair pricing, and fraud detection.

## 🌾 Overview

Agri-Trace is a decentralized application built on Ethereum that enables:
- **End-to-end traceability** of agricultural products through the supply chain
- **QR code verification** for consumers to verify product authenticity
- **Fair pricing mechanisms** to protect farmers with minimum support prices
- **Fraud detection** using statistical analysis and pattern recognition
- **Payment escrow** for secure transactions between supply chain participants
- **Consumer-friendly interface** for easy product verification

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Contracts](#contracts)
- [Installation](#installation)
- [Testing](#testing)
- [Deployment](#deployment)
- [Usage](#usage)
- [Security](#security)
- [Contributing](#contributing)

## ✨ Features

### Core Functionality
- **Product Tracking**: Track products through 9 distinct stages (Planted → Growing → Harvested → Processed → Packaged → In Transit → Distributed → Retail → Sold)
- **Quality Monitoring**: Record temperature, humidity, and quality scores at each stage
- **IPFS Integration**: Store product documentation and certificates on IPFS
- **Role-Based Access Control**: Secure access with farmer, distributor, retailer, and regulator roles

### Advanced Features
- **QR Code Registry**: Link physical QR codes to blockchain product records
- **Fair Pricing**: Enforce minimum support prices with farmer rating bonuses
- **Fraud Detection**: Detect price anomalies and timing violations using statistical methods
- **Payment Escrow**: Secure conditional payments with automatic execution
- **Consumer Interface**: Simplified verification for end consumers

## 🏗️ Architecture

The system consists of 6 main smart contracts:

```
┌─────────────────────┐
│ AgricultureSupplyChain │ (Core tracking)
└──────────┬──────────┘
           │
    ┌──────┴──────┬──────────────┬──────────────┐
    │            │              │              │
┌───▼───┐  ┌────▼────┐  ┌──────▼──────┐  ┌───▼──────┐
│Payment│  │QR Registry│  │Fair Pricing │  │  Fraud   │
│Contract│  │          │  │  Contract   │  │Detection │
└───────┘  └──────────┘  └─────────────┘  └──────────┘
    │            │              │              │
    └────────────┴──────────────┴──────────────┘
                    │
            ┌───────▼────────┐
            │ConsumerInterface│
            └─────────────────┘
```

## 📄 Contracts

### 1. AgricultureSupplyChain
**Core contract for product tracking**
- Manages product lifecycle through 9 stages
- Stores quality data and IPFS hashes
- Handles ownership transfers
- Role-based stage updates

### 2. QRCodeRegistry
**QR code management**
- Registers QR codes linked to products
- Validates QR code authenticity
- Tracks QR code status (active/inactive)

### 3. PaymentContract
**Escrow and payment handling**
- Creates conditional payments
- Manages escrow balances
- Automatic payment execution
- Secure fund transfers

### 4. FairPricingContract
**Price protection for farmers**
- Enforces minimum support prices
- Farmer rating system
- Market price validation
- Volatility protection

### 5. FraudDetectionContract
**Advanced fraud detection**
- Price anomaly detection using statistical methods
- Timing violation detection
- Actor blacklisting
- Comprehensive risk scoring

### 6. ConsumerInterface
**Consumer-friendly verification**
- Simple product verification by ID or QR code
- Farmer reputation display
- Product journey tracking
- Batch verification support

## 🚀 Installation

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (latest version)
- Node.js and pnpm (for package management)
- Git

### Setup

1. **Clone the repository**
```bash
git clone https://github.com/Chitrangath/Agri-Trace.git
cd Agri-Trace
```

2. **Install dependencies**
```bash
forge install OpenZeppelin/openzeppelin-contracts
```

3. **Verify installation**
```bash
forge build
```

## 🧪 Testing

Run all tests:
```bash
forge test
```

Run tests with verbosity:
```bash
forge test -vvv
```

Run specific test file:
```bash
forge test --match-path test/AgricultureSupplyChainTest.t.sol
```

## 📦 Deployment

### Local Deployment

Deploy to local Anvil node:
```bash
# Start Anvil
anvil

# In another terminal, deploy
forge script script/DeployAll.s.sol:DeployAll --rpc-url http://localhost:8545 --broadcast
```

### Sepolia Testnet Deployment

1. **Set up environment variables**
Create a `.env` file:
```bash
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_key
SEPOLIA_ETHERSCAN_API_KEY=your_etherscan_api_key
```

2. **Deploy to Sepolia**
```bash
forge script script/DeploySepolia.s.sol:DeploySepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

3. **Verify contracts on Etherscan**
The `--verify` flag will automatically verify contracts. Alternatively:
```bash
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> \
  --chain sepolia \
  --etherscan-api-key $SEPOLIA_ETHERSCAN_API_KEY
```

### Deployment Addresses

After deployment, addresses are saved to:
- Local: `deployments/all-contracts.env`
- Sepolia: `deployments/sepolia-contracts.env`

## 💻 Usage

### For Farmers

1. **Register as a farmer** (admin only initially):
```solidity
supplyChain.grantFarmerRole(farmerAddress);
fairPricing.registerFarmer(farmerAddress);
```

2. **Create a product**:
```solidity
uint256 productId = supplyChain.createProduct(
    100,                    // quantity
    500,                    // price (in wei)
    locationHash,           // location hash
    ipfsHashes              // array of IPFS hashes
);
```

3. **Update product stage**:
```solidity
supplyChain.updateProductStage(productId, ProductStage.Harvested);
```

4. **Add quality data**:
```solidity
supplyChain.addQualityData(
    productId,
    25,                     // temperature
    50,                     // humidity
    90,                     // quality score
    certificationHash,      // certification hash
    ipfsHash                // IPFS hash
);
```

### For Distributors/Retailers

1. **Get roles**:
```solidity
supplyChain.grantDistributorRole(distributorAddress);
supplyChain.grantRetailerRole(retailerAddress);
```

2. **Transfer ownership**:
```solidity
supplyChain.transferOwnership(productId, newOwner, newPrice);
```

### For Consumers

1. **Verify product by ID**:
```solidity
ProductSummary memory summary = consumerInterface.verifyProduct(productId);
```

2. **Verify product by QR code**:
```solidity
VerificationResult memory result = consumerInterface.verifyByQRCode(qrHash);
```

3. **Get farmer reputation**:
```solidity
FarmerReputation memory reputation = consumerInterface.getFarmerReputation(farmerAddress);
```

### For Administrators

1. **Configure contracts**:
```solidity
consumerInterface.configureContracts(
    supplyChainAddress,
    qrRegistryAddress,
    fairPricingAddress
);
```

2. **Set minimum prices**:
```solidity
fairPricing.updateGlobalMinimumPrice(1 ether);
```

3. **Manage fraud detection**:
```solidity
fraudDetection.updateDetectionConfig(newConfig);
```

## 🔒 Security

### Security Features
- ✅ OpenZeppelin contracts (battle-tested)
- ✅ ReentrancyGuard protection
- ✅ Access control with roles
- ✅ Pausable contracts for emergencies
- ✅ Custom errors for gas efficiency
- ✅ Safe transfer functions (Address.sendValue)

### Security Considerations
- ⚠️ **Price Oracle**: Currently uses a simplified implementation. For production, integrate with Chainlink or similar oracle.
- ⚠️ **Admin Functions**: Consider implementing timelock and multi-sig for production.
- ⚠️ **Upgradeability**: Contracts are not upgradeable. Consider proxy pattern for production if needed.

### Audit Status
⚠️ **Not yet audited**. This code is for testing purposes. A professional security audit is recommended before mainnet deployment.

## 📊 Gas Optimization

The contracts are optimized for gas efficiency:
- Packed structs to minimize storage slots
- Custom errors instead of require strings
- Efficient storage patterns
- Calldata usage for arrays

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📝 License

MIT License - see LICENSE file for details

## 🔗 Links

- [Foundry Documentation](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Sepolia Testnet Faucet](https://sepoliafaucet.com/)

## 📧 Contact

For questions or issues, please open an issue on GitHub.

---

**⚠️ Disclaimer**: This is testnet software. Use at your own risk. Not audited for production use.
