import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { useSupplyChain } from '../hooks/useContracts';
import { Loader, Package, Calendar, DollarSign, User, TrendingUp } from 'lucide-react';

const ProductDetails = () => {
  const { id } = useParams();
  const { getProduct, getQualityHistory } = useSupplyChain();
  const [product, setProduct] = useState(null);
  const [qualityHistory, setQualityHistory] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadProductDetails();
  }, [id]);

  const loadProductDetails = async () => {
    try {
      setLoading(true);
      const productData = await getProduct(id);
      const qualityData = await getQualityHistory(id);
      
      setProduct(productData);
      setQualityHistory(qualityData.qualities || []);
    } catch (error) {
      console.error('Error loading product details:', error);
    } finally {
      setLoading(false);
    }
  };

  const stages = [
    'Planted', 'Growing', 'Harvested', 'Processed',
    'Packaged', 'In Transit', 'Distributed', 'Retail', 'Sold'
  ];

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto fade-in">
        <div className="card text-center py-12">
          <Loader className="w-12 h-12 animate-spin text-primary-700 mx-auto mb-4" />
          <p className="text-gray-600">Loading product details...</p>
        </div>
      </div>
    );
  }

  if (!product) {
    return (
      <div className="max-w-4xl mx-auto fade-in">
        <div className="card text-center py-12">
          <p className="text-gray-600">Product not found</p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto fade-in">
      <div className="card mb-6">
        <div className="flex items-center space-x-3 mb-6">
          <Package className="w-8 h-8 text-primary-700" />
          <h1 className="text-3xl font-bold text-gray-900">Product #{product.id?.toString()}</h1>
        </div>

        <div className="grid md:grid-cols-2 gap-6">
          <div className="space-y-4">
            <div className="flex items-center space-x-3">
              <TrendingUp className="w-5 h-5 text-gray-400" />
              <div>
                <p className="text-sm text-gray-600">Current Stage</p>
                <p className="text-lg font-semibold">{stages[product.stage] || 'Unknown'}</p>
              </div>
            </div>
            <div className="flex items-center space-x-3">
              <Package className="w-5 h-5 text-gray-400" />
              <div>
                <p className="text-sm text-gray-600">Quantity</p>
                <p className="text-lg font-semibold">{product.quantity?.toString()}</p>
              </div>
            </div>
            <div className="flex items-center space-x-3">
              <DollarSign className="w-5 h-5 text-gray-400" />
              <div>
                <p className="text-sm text-gray-600">Price</p>
                <p className="text-lg font-semibold">
                  {(Number(product.price) / 1e18).toFixed(4)} ETH
                </p>
              </div>
            </div>
          </div>

          <div className="space-y-4">
            <div className="flex items-center space-x-3">
              <User className="w-5 h-5 text-gray-400" />
              <div>
                <p className="text-sm text-gray-600">Owner</p>
                <p className="text-lg font-semibold font-mono text-sm break-all">
                  {product.owner}
                </p>
              </div>
            </div>
            <div className="flex items-center space-x-3">
              <Calendar className="w-5 h-5 text-gray-400" />
              <div>
                <p className="text-sm text-gray-600">Created</p>
                <p className="text-lg font-semibold">
                  {new Date(Number(product.timestamp) * 1000).toLocaleString()}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {qualityHistory.length > 0 && (
        <div className="card">
          <h2 className="text-2xl font-bold text-gray-900 mb-4">Quality History</h2>
          <div className="space-y-4">
            {qualityHistory.map((quality, index) => (
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
    </div>
  );
};

export default ProductDetails;
