import React, { useState } from 'react';
import { useConsumerInterface } from '../hooks/useContracts';
import { useWeb3 } from '../contexts/Web3Context';
import { QrCode, Camera, Loader, CheckCircle, XCircle } from 'lucide-react';
import { ethers } from 'ethers';

const QRScan = () => {
  const [qrHash, setQrHash] = useState('');
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const { isConnected } = useWeb3();
  const { verifyByQRCode } = useConsumerInterface();

  const handleScan = async (e) => {
    e.preventDefault();
    if (!qrHash) return;

    setLoading(true);
    setResult(null);

    try {
      if (!isConnected) {
        throw new Error('Please connect your wallet first');
      }

      // Convert string to bytes32 hash
      const hashBytes = ethers.keccak256(ethers.toUtf8Bytes(qrHash));
      
      const verificationResult = await verifyByQRCode(hashBytes);
      
      setResult({
        isValid: verificationResult.isValid,
        status: verificationResult.status,
        productId: verificationResult.productId?.toString(),
        farmerName: verificationResult.farmerName,
        rating: verificationResult.rating?.toString(),
      });
    } catch (error) {
      setResult({
        isValid: false,
        status: error.message || 'Failed to verify QR code',
        productId: null,
        farmerName: '',
        rating: '0',
      });
      console.error('QR verification error:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto fade-in">
      <div className="card mb-6">
        <div className="flex items-center space-x-3 mb-6">
          <QrCode className="w-8 h-8 text-primary-700" />
          <h1 className="text-3xl font-bold text-gray-900">QR Code Verification</h1>
        </div>

        <form onSubmit={handleScan} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              QR Code Hash or String
            </label>
            <div className="flex space-x-2">
              <input
                type="text"
                value={qrHash}
                onChange={(e) => setQrHash(e.target.value)}
                placeholder="Enter QR code hash or scan QR code"
                className="input flex-1"
                disabled={loading}
              />
              <button
                type="submit"
                disabled={loading || !qrHash}
                className="btn-primary flex items-center space-x-2"
              >
                {loading ? (
                  <>
                    <Loader className="w-4 h-4 animate-spin" />
                    <span>Verifying...</span>
                  </>
                ) : (
                  <>
                    <Camera className="w-4 h-4" />
                    <span>Verify</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </form>

        <p className="text-sm text-gray-500 mt-4">
          Enter the QR code hash or scan a QR code to verify product authenticity.
        </p>
      </div>

      {result && (
        <div className="card">
          <div className="flex items-center space-x-3 mb-4">
            {result.isValid ? (
              <CheckCircle className="w-8 h-8 text-green-500" />
            ) : (
              <XCircle className="w-8 h-8 text-red-500" />
            )}
            <h2 className="text-2xl font-bold text-gray-900">Verification Result</h2>
          </div>

          <div className="space-y-4">
            <div className="p-4 bg-gray-50 rounded-lg">
              <p className="text-sm text-gray-600 mb-1">Status</p>
              <p className={`text-lg font-semibold ${result.isValid ? 'text-green-600' : 'text-red-600'}`}>
                {result.status}
              </p>
            </div>

            {result.isValid && (
              <>
                <div className="grid md:grid-cols-2 gap-4">
                  <div className="p-4 bg-gray-50 rounded-lg">
                    <p className="text-sm text-gray-600 mb-1">Product ID</p>
                    <p className="text-lg font-semibold">{result.productId}</p>
                  </div>
                  <div className="p-4 bg-gray-50 rounded-lg">
                    <p className="text-sm text-gray-600 mb-1">Farmer Name</p>
                    <p className="text-lg font-semibold">{result.farmerName || 'Not set'}</p>
                  </div>
                  <div className="p-4 bg-gray-50 rounded-lg">
                    <p className="text-sm text-gray-600 mb-1">Farmer Rating</p>
                    <p className="text-lg font-semibold">
                      {result.rating ? `${result.rating}/100` : 'N/A'}
                    </p>
                  </div>
                </div>

                {result.productId && (
                  <a
                    href={`/product/${result.productId}`}
                    className="btn-primary w-full text-center block"
                  >
                    View Product Details
                  </a>
                )}
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default QRScan;
