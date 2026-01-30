import React, { useState, useEffect } from 'react';
import { useWeb3 } from '../contexts/Web3Context';
import { useSupplyChain, useQRCodeRegistry } from '../hooks/useContracts';
import { getContract } from '../utils/web3';
import { Plus, Package, TrendingUp, QrCode, Loader } from 'lucide-react';
import { ethers } from 'ethers';

const FarmerDashboard = () => {
  const { account, isConnected } = useWeb3();
  const { createProduct, updateProductStage, addQualityData, loading } = useSupplyChain();
  const { registerQRCode, loading: qrLoading } = useQRCodeRegistry();
  
  const [products, setProducts] = useState([]);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [formData, setFormData] = useState({
    quantity: '',
    price: '',
    locationHash: '',
    ipfsHashes: '',
  });

  useEffect(() => {
    if (isConnected && account) {
      loadProducts();
    }
  }, [isConnected, account]);

  const loadProducts = async () => {
    try {
      const contract = await getContract('AgricultureSupplyChain');
      const productIds = await contract.ownerProducts(account);
      
      const productPromises = productIds.map(async (id) => {
        const product = await contract.getProduct(id);
        return {
          id: id.toString(),
          quantity: product[2].toString(),
          price: product[3].toString(),
          owner: product[4],
          stage: product[5],
          timestamp: product[1].toString(),
        };
      });
      
      const productsData = await Promise.all(productPromises);
      setProducts(productsData);
    } catch (error) {
      console.error('Error loading products:', error);
    }
  };

  const handleCreateProduct = async (e) => {
    e.preventDefault();
    try {
      const quantity = parseInt(formData.quantity);
      const price = ethers.parseEther(formData.price);
      const locationHash = ethers.keccak256(ethers.toUtf8Bytes(formData.locationHash));
      const ipfsHashes = formData.ipfsHashes ? formData.ipfsHashes.split(',').map(h => h.trim()) : [];

      const { productId } = await createProduct(quantity, price, locationHash, ipfsHashes);
      
      setFormData({ quantity: '', price: '', locationHash: '', ipfsHashes: '' });
      setShowCreateForm(false);
      await loadProducts();
    } catch (error) {
      console.error('Error creating product:', error);
    }
  };

  const handleUpdateStage = async (productId, newStage) => {
    try {
      await updateProductStage(productId, newStage);
      await loadProducts();
    } catch (error) {
      console.error('Error updating stage:', error);
    }
  };

  const handleAddQuality = async (productId) => {
    const temp = prompt('Enter temperature:');
    const humidity = prompt('Enter humidity:');
    const score = prompt('Enter quality score (0-100):');
    const ipfsHash = prompt('Enter IPFS hash (optional):') || '';

    if (temp && humidity && score) {
      try {
        await addQualityData(
          productId,
          parseInt(temp),
          parseInt(humidity),
          parseInt(score),
          ethers.ZeroHash,
          ipfsHash
        );
        await loadProducts();
      } catch (error) {
        console.error('Error adding quality data:', error);
      }
    }
  };

  const stages = [
    'Planted', 'Growing', 'Harvested', 'Processed',
    'Packaged', 'In Transit', 'Distributed', 'Retail', 'Sold'
  ];

  if (!isConnected) {
    return (
      <div className="max-w-4xl mx-auto fade-in">
        <div className="card text-center">
          <h2 className="text-2xl font-bold text-gray-900 mb-4">Connect Your Wallet</h2>
          <p className="text-gray-600">Please connect your wallet to access the farmer dashboard.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto fade-in">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Farmer Dashboard</h1>
        <button
          onClick={() => setShowCreateForm(!showCreateForm)}
          className="btn-primary flex items-center space-x-2"
        >
          <Plus className="w-4 h-4" />
          <span>Create Product</span>
        </button>
      </div>

      {showCreateForm && (
        <div className="card mb-6">
          <h2 className="text-xl font-bold text-gray-900 mb-4">Create New Product</h2>
          <form onSubmit={handleCreateProduct} className="space-y-4">
            <div className="grid md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Quantity
                </label>
                <input
                  type="number"
                  value={formData.quantity}
                  onChange={(e) => setFormData({ ...formData, quantity: e.target.value })}
                  className="input"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Price (ETH)
                </label>
                <input
                  type="number"
                  step="0.0001"
                  value={formData.price}
                  onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                  className="input"
                  required
                />
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Location Hash
              </label>
              <input
                type="text"
                value={formData.locationHash}
                onChange={(e) => setFormData({ ...formData, locationHash: e.target.value })}
                className="input"
                placeholder="Enter location identifier"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                IPFS Hashes (comma-separated, optional)
              </label>
              <input
                type="text"
                value={formData.ipfsHashes}
                onChange={(e) => setFormData({ ...formData, ipfsHashes: e.target.value })}
                className="input"
                placeholder="QmHash1, QmHash2"
              />
            </div>
            <div className="flex space-x-2">
              <button type="submit" className="btn-primary" disabled={loading}>
                {loading ? 'Creating...' : 'Create Product'}
              </button>
              <button
                type="button"
                onClick={() => setShowCreateForm(false)}
                className="btn-secondary"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="grid gap-6">
        {products.length === 0 ? (
          <div className="card text-center py-12">
            <Package className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600">No products found. Create your first product!</p>
          </div>
        ) : (
          products.map((product) => (
            <div key={product.id} className="card">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-xl font-bold text-gray-900">Product #{product.id}</h3>
                  <p className="text-sm text-gray-500">
                    Created: {new Date(Number(product.timestamp) * 1000).toLocaleDateString()}
                  </p>
                </div>
                <span className="px-3 py-1 bg-primary-200 text-primary-800 rounded-full text-sm font-medium shadow-sm">
                  {stages[product.stage]}
                </span>
              </div>

              <div className="grid md:grid-cols-3 gap-4 mb-4">
                <div>
                  <p className="text-sm text-gray-600">Quantity</p>
                  <p className="text-lg font-semibold">{product.quantity}</p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Price</p>
                  <p className="text-lg font-semibold">
                    {(Number(product.price) / 1e18).toFixed(4)} ETH
                  </p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Stage</p>
                  <p className="text-lg font-semibold">{stages[product.stage]}</p>
                </div>
              </div>

              <div className="flex space-x-2">
                {product.stage < 8 && (
                  <button
                    onClick={() => handleUpdateStage(product.id, product.stage + 1)}
                    className="btn-primary text-sm"
                    disabled={loading}
                  >
                    Update to {stages[product.stage + 1]}
                  </button>
                )}
                <button
                  onClick={() => handleAddQuality(product.id)}
                  className="btn-secondary text-sm"
                  disabled={loading}
                >
                  Add Quality Data
                </button>
                <a
                  href={`/product/${product.id}`}
                  className="btn-secondary text-sm"
                >
                  View Details
                </a>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default FarmerDashboard;
