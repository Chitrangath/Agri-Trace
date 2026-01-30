# Frontend Setup Guide

## Quick Start

1. **Install dependencies:**
```bash
cd frontend
npm install
```

2. **Build contracts (in root directory):**
```bash
cd ..
forge build
cd frontend
```

3. **Copy contract ABIs:**
```bash
chmod +x copy-abis.sh
./copy-abis.sh
```

Or manually:
```bash
mkdir -p public/abis
cp ../out/*/**.json public/abis/
```

4. **Update contract addresses:**
After deploying to Sepolia, update `src/config/contracts.js` with your deployed addresses.

5. **Start development server:**
```bash
npm run dev
```

## After Deploying Contracts

1. Deploy contracts to Sepolia using the deployment script
2. Copy the contract addresses from `deployments/sepolia-contracts.env`
3. Update `src/config/contracts.js`:
```javascript
export const CONTRACT_ADDRESSES = {
  sepolia: {
    SUPPLY_CHAIN: '0xYourAddress',
    PAYMENT: '0xYourAddress',
    QR_REGISTRY: '0xYourAddress',
    FAIR_PRICING: '0xYourAddress',
    CONSUMER_INTERFACE: '0xYourAddress',
    FRAUD_DETECTION: '0xYourAddress',
  }
};
```

4. Rebuild and deploy frontend

## Features Implemented

✅ Wallet connection (MetaMask)
✅ Product verification by ID
✅ QR code verification
✅ Farmer dashboard
✅ Product creation
✅ Stage updates
✅ Quality data addition
✅ Product details view
✅ Quality history display

## Next Steps

- Add QR code scanner (camera integration)
- Add IPFS file upload
- Add transaction history
- Add farmer reputation display
- Add fraud detection alerts
