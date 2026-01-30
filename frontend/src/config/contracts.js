// Contract addresses - Update these after deploying to Sepolia
export const CONTRACT_ADDRESSES = {
  // Sepolia Testnet addresses (update after deployment)
  sepolia: {
    SUPPLY_CHAIN: '0x0000000000000000000000000000000000000000', // Update after deployment
    PAYMENT: '0x0000000000000000000000000000000000000000',
    QR_REGISTRY: '0x0000000000000000000000000000000000000000',
    FAIR_PRICING: '0x0000000000000000000000000000000000000000',
    CONSUMER_INTERFACE: '0x0000000000000000000000000000000000000000',
    FRAUD_DETECTION: '0x0000000000000000000000000000000000000000',
  },
  // Local development (Anvil)
  localhost: {
    SUPPLY_CHAIN: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    PAYMENT: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    QR_REGISTRY: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    FAIR_PRICING: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
    CONSUMER_INTERFACE: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
    FRAUD_DETECTION: '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707',
  }
};

// Network configurations
export const NETWORKS = {
  sepolia: {
    chainId: '0xaa36a7', // 11155111
    chainName: 'Sepolia',
    nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
    rpcUrls: ['https://sepolia.infura.io/v3/'],
    blockExplorerUrls: ['https://sepolia.etherscan.io']
  },
  localhost: {
    chainId: '0x7a69', // 31337
    chainName: 'Localhost',
    nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
    rpcUrls: ['http://localhost:8545'],
    blockExplorerUrls: []
  }
};

// Get contract addresses based on current network
export const getContractAddresses = (chainId) => {
  if (chainId === '0xaa36a7' || chainId === 11155111) {
    return CONTRACT_ADDRESSES.sepolia;
  } else if (chainId === '0x7a69' || chainId === 31337) {
    return CONTRACT_ADDRESSES.localhost;
  }
  return CONTRACT_ADDRESSES.sepolia; // Default to Sepolia
};
