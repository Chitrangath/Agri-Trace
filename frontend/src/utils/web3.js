import { ethers } from 'ethers';
import { getContractAddresses } from '../config/contracts.js';
import { loadContractABI } from './contractLoader.js';

/**
 * Initialize Web3 Provider
 */
export const getProvider = () => {
  if (typeof window.ethereum !== 'undefined') {
    return new ethers.BrowserProvider(window.ethereum);
  }
  throw new Error('MetaMask is not installed');
};

/**
 * Get Signer from connected wallet
 */
export const getSigner = async () => {
  const provider = getProvider();
  return await provider.getSigner();
};

/**
 * Get Contract Instance
 */
export const getContract = async (contractName, address = null) => {
  try {
    const signer = await getSigner();
    const chainId = await signer.provider.getNetwork().then(n => n.chainId);
    const addresses = getContractAddresses(chainId);
    
    const contractAddress = address || addresses[contractName.toUpperCase().replace(/([A-Z])/g, '_$1').slice(1)] || addresses[contractName];
    
    if (!contractAddress || contractAddress === '0x0000000000000000000000000000000000000000') {
      throw new Error(`Contract address not set for ${contractName}`);
    }
    
    const abi = await loadContractABI(contractName);
    return new ethers.Contract(contractAddress, abi, signer);
  } catch (error) {
    console.error(`Error getting contract ${contractName}:`, error);
    throw error;
  }
};

/**
 * Connect Wallet
 */
export const connectWallet = async () => {
  if (typeof window.ethereum === 'undefined') {
    throw new Error('Please install MetaMask');
  }
  
  try {
    const accounts = await window.ethereum.request({
      method: 'eth_requestAccounts'
    });
    return accounts[0];
  } catch (error) {
    console.error('Error connecting wallet:', error);
    throw error;
  }
};

/**
 * Switch or Add Network
 */
export const switchNetwork = async (chainId) => {
  if (typeof window.ethereum === 'undefined') {
    throw new Error('MetaMask is not installed');
  }
  
  try {
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId }],
    });
  } catch (switchError) {
    // This error code indicates that the chain has not been added to MetaMask
    if (switchError.code === 4902) {
      // Add the chain
      const networkConfig = {
        sepolia: {
          chainId: '0xaa36a7',
          chainName: 'Sepolia',
          nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
          rpcUrls: ['https://sepolia.infura.io/v3/'],
          blockExplorerUrls: ['https://sepolia.etherscan.io']
        }
      };
      
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [networkConfig.sepolia],
      });
    } else {
      throw switchError;
    }
  }
};

/**
 * Get Current Account
 */
export const getCurrentAccount = async () => {
  if (typeof window.ethereum === 'undefined') {
    return null;
  }
  
  try {
    const accounts = await window.ethereum.request({
      method: 'eth_accounts'
    });
    return accounts[0] || null;
  } catch (error) {
    console.error('Error getting current account:', error);
    return null;
  }
};

/**
 * Get Network Info
 */
export const getNetworkInfo = async () => {
  if (typeof window.ethereum === 'undefined') {
    return null;
  }
  
  try {
    const provider = getProvider();
    const network = await provider.getNetwork();
    return {
      chainId: network.chainId.toString(),
      name: network.name
    };
  } catch (error) {
    console.error('Error getting network info:', error);
    return null;
  }
};

/**
 * Format Address
 */
export const formatAddress = (address) => {
  if (!address) return '';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
};

/**
 * Format Ether
 */
export const formatEther = (value) => {
  if (!value) return '0';
  return ethers.formatEther(value);
};

/**
 * Parse Ether
 */
export const parseEther = (value) => {
  return ethers.parseEther(value.toString());
};

/**
 * Wait for Transaction
 */
export const waitForTransaction = async (txHash) => {
  const provider = getProvider();
  return await provider.waitForTransaction(txHash);
};
