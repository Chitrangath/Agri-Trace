import React, { createContext, useContext, useState, useEffect } from 'react';
import { connectWallet, getCurrentAccount, getNetworkInfo, switchNetwork } from '../utils/web3.js';
import toast from 'react-hot-toast';

const Web3Context = createContext();

export const useWeb3 = () => {
  const context = useContext(Web3Context);
  if (!context) {
    throw new Error('useWeb3 must be used within Web3Provider');
  }
  return context;
};

export const Web3Provider = ({ children }) => {
  const [account, setAccount] = useState(null);
  const [network, setNetwork] = useState(null);
  const [isConnecting, setIsConnecting] = useState(false);
  const [isConnected, setIsConnected] = useState(false);

  // Check if wallet is already connected
  useEffect(() => {
    checkConnection();
    
    // Listen for account changes
    if (window.ethereum) {
      window.ethereum.on('accountsChanged', handleAccountsChanged);
      window.ethereum.on('chainChanged', handleChainChanged);
    }

    return () => {
      if (window.ethereum) {
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
        window.ethereum.removeListener('chainChanged', handleChainChanged);
      }
    };
  }, []);

  const checkConnection = async () => {
    try {
      const currentAccount = await getCurrentAccount();
      const networkInfo = await getNetworkInfo();
      
      if (currentAccount) {
        setAccount(currentAccount);
        setNetwork(networkInfo);
        setIsConnected(true);
      }
    } catch (error) {
      console.error('Error checking connection:', error);
    }
  };

  const handleAccountsChanged = (accounts) => {
    if (accounts.length === 0) {
      setAccount(null);
      setIsConnected(false);
      toast.error('Wallet disconnected');
    } else {
      setAccount(accounts[0]);
      setIsConnected(true);
      toast.success('Wallet connected');
    }
  };

  const handleChainChanged = (chainId) => {
    window.location.reload();
  };

  const connect = async () => {
    setIsConnecting(true);
    try {
      const account = await connectWallet();
      const networkInfo = await getNetworkInfo();
      
      setAccount(account);
      setNetwork(networkInfo);
      setIsConnected(true);
      
      toast.success('Wallet connected successfully!');
    } catch (error) {
      console.error('Error connecting wallet:', error);
      toast.error(error.message || 'Failed to connect wallet');
    } finally {
      setIsConnecting(false);
    }
  };

  const switchToSepolia = async () => {
    try {
      await switchNetwork('0xaa36a7');
      toast.success('Switched to Sepolia network');
      window.location.reload();
    } catch (error) {
      console.error('Error switching network:', error);
      toast.error(error.message || 'Failed to switch network');
    }
  };

  const disconnect = () => {
    setAccount(null);
    setNetwork(null);
    setIsConnected(false);
    toast.info('Wallet disconnected');
  };

  const value = {
    account,
    network,
    isConnecting,
    isConnected,
    connect,
    disconnect,
    switchToSepolia,
  };

  return <Web3Context.Provider value={value}>{children}</Web3Context.Provider>;
};
