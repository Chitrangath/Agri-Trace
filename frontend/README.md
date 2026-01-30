# Agri-Trace Frontend

Modern React frontend for the Agri-Trace blockchain supply chain application.

## Features

- 🔗 **Wallet Connection** - Connect with MetaMask
- 🔍 **Product Verification** - Verify products by ID
- 📱 **QR Code Scanning** - Scan and verify QR codes
- 👨‍🌾 **Farmer Dashboard** - Manage products and supply chain
- 📊 **Product Details** - View complete product information
- 🎨 **Modern UI** - Built with Tailwind CSS

## Tech Stack

- **React 18** - UI framework
- **Vite** - Build tool
- **Ethers.js 6** - Ethereum interaction
- **React Router** - Navigation
- **Tailwind CSS** - Styling
- **React Hot Toast** - Notifications
- **Lucide React** - Icons

## Installation

1. **Install dependencies:**
```bash
cd frontend
npm install
```

2. **Update contract addresses:**
Edit `src/config/contracts.js` and update the contract addresses after deploying to Sepolia.

3. **Copy contract ABIs (optional):**
After running `forge build`, copy ABIs from `out/` to `public/abis/`:
```bash
mkdir -p public/abis
cp ../out/ConsumerInterface.sol/ConsumerInterface.json public/abis/
cp ../out/AgricultureSupplyChain.sol/AgricultureSupplyChain.json public/abis/
# ... repeat for other contracts
```

## Development

Start the development server:
```bash
npm run dev
```

The app will open at `http://localhost:3000`

## Building for Production

```bash
npm run build
```

The built files will be in `dist/` directory.

## Configuration

### Contract Addresses

Update contract addresses in `src/config/contracts.js`:

```javascript
export const CONTRACT_ADDRESSES = {
  sepolia: {
    SUPPLY_CHAIN: '0x...', // Your deployed address
    CONSUMER_INTERFACE: '0x...',
    // ... other contracts
  }
};
```

### Network Configuration

The app automatically detects the network. To switch networks, use the MetaMask network switcher or configure in `src/config/contracts.js`.

## Project Structure

```
frontend/
├── src/
│   ├── components/       # React components
│   │   ├── Navbar.jsx
│   │   ├── Home.jsx
│   │   ├── VerifyProduct.jsx
│   │   ├── QRScan.jsx
│   │   ├── FarmerDashboard.jsx
│   │   └── ProductDetails.jsx
│   ├── contexts/         # React contexts
│   │   └── Web3Context.jsx
│   ├── hooks/            # Custom hooks
│   │   └── useContracts.js
│   ├── utils/            # Utility functions
│   │   ├── web3.js
│   │   └── contractLoader.js
│   ├── config/          # Configuration
│   │   └── contracts.js
│   ├── App.jsx           # Main app component
│   └── main.jsx          # Entry point
├── public/               # Static files
└── package.json
```

## Usage

### Connect Wallet

Click "Connect Wallet" in the navbar to connect MetaMask.

### Verify Product

1. Navigate to "Verify Product"
2. Enter product ID
3. Click "Verify"
4. View product details

### Scan QR Code

1. Navigate to "QR Scan"
2. Enter QR code hash or scan QR code
3. View verification result

### Farmer Dashboard

1. Connect wallet with farmer account
2. Navigate to "Farmer Dashboard"
3. Create products, update stages, add quality data

## Environment Variables

Create a `.env` file for environment-specific configuration:

```env
VITE_NETWORK=sepolia
VITE_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
```

## Troubleshooting

### "Contract address not set"
- Update contract addresses in `src/config/contracts.js`
- Ensure you're on the correct network

### "MetaMask is not installed"
- Install MetaMask browser extension
- Refresh the page

### "Failed to connect wallet"
- Check MetaMask is unlocked
- Ensure you approve the connection request

### "Transaction failed"
- Check you have enough ETH for gas
- Verify contract addresses are correct
- Check you're on the correct network

## Deployment

### Netlify

1. Build the project: `npm run build`
2. Deploy `dist/` folder to Netlify
3. Configure environment variables in Netlify dashboard

### Vercel

1. Connect your GitHub repository
2. Set build command: `npm run build`
3. Set output directory: `dist`
4. Deploy

## License

MIT
