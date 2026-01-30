import { useState, useCallback } from 'react';
import { getContract } from '../utils/web3.js';
import toast from 'react-hot-toast';

/**
 * Hook for ConsumerInterface contract
 */
export const useConsumerInterface = () => {
  const [loading, setLoading] = useState(false);

  const verifyProduct = useCallback(async (productId) => {
    setLoading(true);
    try {
      const contract = await getContract('ConsumerInterface');
      const tx = await contract.verifyProduct(productId);
      const receipt = await tx.wait();
      toast.success('Product verified successfully!');
      return receipt;
    } catch (error) {
      console.error('Error verifying product:', error);
      toast.error(error.reason || 'Failed to verify product');
      throw error;
    } finally {
      setLoading(false);
    }
  }, []);

  const verifyByQRCode = useCallback(async (qrHash) => {
    setLoading(true);
    try {
      const contract = await getContract('ConsumerInterface');
      const result = await contract.verifyByQRCode(qrHash);
      return result;
    } catch (error) {
      console.error('Error verifying QR code:', error);
      toast.error(error.reason || 'Failed to verify QR code');
      throw error;
    } finally {
      setLoading(false);
    }
  }, []);

  const getFarmerReputation = useCallback(async (farmerAddress) => {
    try {
      const contract = await getContract('ConsumerInterface');
      const reputation = await contract.getFarmerReputation(farmerAddress);
      return reputation;
    } catch (error) {
      console.error('Error getting farmer reputation:', error);
      throw error;
    }
  }, []);

  const getProductJourney = useCallback(async (productId) => {
    try {
      const contract = await getContract('ConsumerInterface');
      const journey = await contract.getProductJourney(productId);
      return journey;
    } catch (error) {
      console.error('Error getting product journey:', error);
      throw error;
    }
  }, []);

  return {
    loading,
    verifyProduct,
    verifyByQRCode,
    getFarmerReputation,
    getProductJourney,
  };
};

/**
 * Hook for AgricultureSupplyChain contract
 */
export const useSupplyChain = () => {
  const [loading, setLoading] = useState(false);

  const createProduct = useCallback(async (quantity, price, locationHash, ipfsHashes = []) => {
    setLoading(true);
    try {
      const contract = await getContract('AgricultureSupplyChain');
      const tx = await contract.createProduct(quantity, price, locationHash, ipfsHashes);
      const receipt = await tx.wait();
      const productId = receipt.logs[0]?.args?.productId || receipt.logs[0]?.args?.[0];
      toast.success(`Product created! ID: ${productId?.toString()}`);
      return { receipt, productId };
    } catch (error) {
      console.error('Error creating product:', error);
      toast.error(error.reason || 'Failed to create product');
      throw error;
    } finally {
      setLoading(false);
    }
  }, []);

  const updateProductStage = useCallback(async (productId, stage) => {
    setLoading(true);
    try {
      const contract = await getContract('AgricultureSupplyChain');
      const tx = await contract.updateProductStage(productId, stage);
      const receipt = await tx.wait();
      toast.success('Product stage updated!');
      return receipt;
    } catch (error) {
      console.error('Error updating product stage:', error);
      toast.error(error.reason || 'Failed to update product stage');
      throw error;
    } finally {
      setLoading(false);
    }
  }, []);

  const addQualityData = useCallback(async (productId, temperature, humidity, qualityScore, certificationHash, ipfsHash) => {
    setLoading(true);
    try {
      const contract = await getContract('AgricultureSupplyChain');
      const tx = await contract.addQualityData(productId, temperature, humidity, qualityScore, certificationHash, ipfsHash);
      const receipt = await tx.wait();
      toast.success('Quality data added!');
      return receipt;
    } catch (error) {
      console.error('Error adding quality data:', error);
      toast.error(error.reason || 'Failed to add quality data');
      throw error;
    } finally {
      setLoading(false);
    }
  }, []);

  const getProduct = useCallback(async (productId) => {
    try {
      const contract = await getContract('AgricultureSupplyChain');
      const product = await contract.getProduct(productId);
      return {
        id: product[0],
        timestamp: product[1],
        quantity: product[2],
        price: product[3],
        owner: product[4],
        stage: product[5],
      };
    } catch (error) {
      console.error('Error getting product:', error);
      throw error;
    }
  }, []);

  const getQualityHistory = useCallback(async (productId) => {
    try {
      const contract = await getContract('AgricultureSupplyChain');
      const [qualities, ipfsHashes] = await contract.getQualityHistory(productId);
      return { qualities, ipfsHashes };
    } catch (error) {
      console.error('Error getting quality history:', error);
      throw error;
    }
  }, []);

  return {
    loading,
    createProduct,
    updateProductStage,
    addQualityData,
    getProduct,
    getQualityHistory,
  };
};

/**
 * Hook for QRCodeRegistry contract
 */
export const useQRCodeRegistry = () => {
  const [loading, setLoading] = useState(false);

  const registerQRCode = useCallback(async (qrHash, productId, ipfsMetadataHash = '') => {
    setLoading(true);
    try {
      const contract = await getContract('QRCodeRegistry');
      const tx = await contract.registerQRCode(qrHash, productId, ipfsMetadataHash);
      const receipt = await tx.wait();
      toast.success('QR code registered!');
      return receipt;
    } catch (error) {
      console.error('Error registering QR code:', error);
      toast.error(error.reason || 'Failed to register QR code');
      throw error;
    } finally {
      setLoading(false);
    }
  }, []);

  const getProductFromQR = useCallback(async (qrHash) => {
    try {
      const contract = await getContract('QRCodeRegistry');
      const productId = await contract.getProductFromQR(qrHash);
      return productId;
    } catch (error) {
      console.error('Error getting product from QR:', error);
      throw error;
    }
  }, []);

  return {
    loading,
    registerQRCode,
    getProductFromQR,
  };
};
