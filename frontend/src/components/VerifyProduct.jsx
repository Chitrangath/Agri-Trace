import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useWeb3 } from '../contexts/Web3Context';
import { useConsumerInterface, useSupplyChain } from '../hooks/useContracts';
import { Search, Loader, AlertCircle } from 'lucide-react';

const VerifyProduct = () => {
  const [productId, setProductId] = useState('');
  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const { isConnected } = useWeb3();
  const { verifyProduct } = useConsumerInterface();
  const { getProduct, getQualityHistory } = useSupplyChain();
  const navigate = useNavigate();

  const handleVerify = async (e) => {
    e.preventDefault();
    if (!productId) return;

    setLoading(true);
    setError(null);
    setProduct(null);

    try {
      if (!isConnected) {
        throw new Error('Please connect your wallet first');
      }

      // Verify product using ConsumerInterface
      await verifyProduct(productId);

      // Get detailed product information
      const productData = await getProduct(productId);
      const qualityData = await getQualityHistory(productId);

      setProduct({
        ...productData,
        qualityHistory: qualityData.qualities,
        ipfsHashes: qualityData.ipfsHashes,
      });
    } catch (err) {
      setError(err.message || 'Failed to verify product');
      console.error('Verification error:', err);
    } finally {
      setLoading(false);
    }
  };

  const stages = [
    'Planted',
    'Growing',
    'Harvested',
    'Processed',
    'Packaged',
    'In Transit',
    'Distributed',
    'Retail',
    'Sold',
  ];

  return (
    <div className="max-w-4xl mx-auto fade-in">
      <div className="card mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-6">Verify Product</h1>
        
        <form onSubmit={handleVerify} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Product ID
            </label>
            <div className="flex space-x-2">
              <input
                type="text"
                value={productId}
                onChange={(e) => setProductId(e.target.value)}
                placeholder="Enter product ID"
                className="input flex-1"
                disabled={loading}
              />
              <button
                type="submit"
                disabled={loading || !productId}
                className="btn-primary flex items-center space-x-2"
              >
                {loading ? (
                  <>
                    <Loader className="w-4 h-4 animate-spin text-white" />
                    <span>Verifying...</span>
                  </>
                ) : (
                  <>
                    <Search className="w-4 h-4" />
                    <span>Verify</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </form>

        {error && (
          <div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center space-x-2 text-red-700">
            <AlertCircle className="w-5 h-5" />
            <span>{error}</span>
          </div>
        )}
      </div>

      {product && (
        <div className="space-y-6">
          {/* Product Summary */}
          <div className="card">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Product Information</h2>
            <div className="grid md:grid-cols-2 gap-4">
              <div>
                <p className="text-sm text-gray-600">Product ID</p>
                <p className="text-lg font-semibold">{product.id?.toString()}</p>
              </div>
              <div>
                <p className="text-sm text-gray-600">Current Stage</p>
                <p className="text-lg font-semibold">{stages[product.stage] || 'Unknown'}</p>
              </div>
              <div>
                <p className="text-sm text-gray-600">Quantity</p>
                <p className="text-lg font-semibold">{product.quantity?.toString()}</p>
              </div>
              <div>
                <p className="text-sm text-gray-600">Price</p>
                <p className="text-lg font-semibold">
                  {(Number(product.price) / 1e18).toFixed(4)} ETH
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-600">Owner</p>
                <p className="text-lg font-semibold font-mono text-sm">
                  {product.owner}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-600">Created</p>
                <p className="text-lg font-semibold">
                  {new Date(Number(product.timestamp) * 1000).toLocaleDateString()}
                </p>
              </div>
            </div>
          </div>

          {/* Quality History */}
          {product.qualityHistory && product.qualityHistory.length > 0 && (
            <div className="card">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">Quality History</h2>
              <div className="space-y-4">
                {product.qualityHistory.map((quality, index) => (
                  <div
                    key={index}
                    className="p-4 bg-gray-50 rounded-lg border border-gray-200"
                  >
                    <div className="grid md:grid-cols-4 gap-4">
                      <div>
                        <p className="text-sm text-gray-600">Quality Score</p>
                        <p className="text-lg font-semibold">{quality.qualityScore?.toString()}</p>
                      </div>
                      <div>
                        <p className="text-sm text-gray-600">Temperature</p>
                        <p className="text-lg font-semibold">{quality.temperature?.toString()}°C</p>
                      </div>
                      <div>
                        <p className="text-sm text-gray-600">Humidity</p>
                        <p className="text-lg font-semibold">{quality.humidity?.toString()}%</p>
                      </div>
                      <div>
                        <p className="text-sm text-gray-600">Date</p>
                        <p className="text-lg font-semibold">
                          {new Date(Number(quality.timestamp) * 1000).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          <button
            onClick={() => navigate(`/product/${product.id}`)}
            className="btn-primary w-full"
          >
            View Full Details
          </button>
        </div>
      )}
    </div>
  );
};

export default VerifyProduct;
