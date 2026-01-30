import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useWeb3 } from '../contexts/Web3Context';
import { formatAddress } from '../utils/web3';
import { Sprout, Wallet, LogOut } from 'lucide-react';

const Navbar = () => {
  const { account, isConnected, connect, disconnect, switchToSepolia } = useWeb3();
  const location = useLocation();

  const isActive = (path) => location.pathname === path;

  return (
    <nav className="bg-white shadow-md sticky top-0 z-50">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link to="/" className="flex items-center space-x-2">
            <Sprout className="w-8 h-8 text-primary-700" />
            <span className="text-xl font-bold text-earth-800">Agri-Trace</span>
          </Link>

          {/* Navigation Links */}
          <div className="hidden md:flex items-center space-x-6">
            <Link
              to="/"
              className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                isActive('/') ? 'text-primary-700 bg-primary-100' : 'text-earth-700 hover:text-primary-700'
              }`}
            >
              Home
            </Link>
            <Link
              to="/verify"
              className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                isActive('/verify') ? 'text-primary-600 bg-primary-50' : 'text-gray-700 hover:text-primary-600'
              }`}
            >
              Verify Product
            </Link>
            <Link
              to="/qr-scan"
              className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                isActive('/qr-scan') ? 'text-primary-600 bg-primary-50' : 'text-gray-700 hover:text-primary-600'
              }`}
            >
              QR Scan
            </Link>
            <Link
              to="/farmer"
              className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                isActive('/farmer') ? 'text-primary-600 bg-primary-50' : 'text-gray-700 hover:text-primary-600'
              }`}
            >
              Farmer Dashboard
            </Link>
          </div>

          {/* Wallet Connection */}
          <div className="flex items-center space-x-4">
            {isConnected ? (
              <div className="flex items-center space-x-3">
                <div className="flex items-center space-x-2 bg-green-50 px-3 py-2 rounded-lg">
                  <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                  <span className="text-sm font-medium text-gray-700">
                    {formatAddress(account)}
                  </span>
                </div>
                <button
                  onClick={disconnect}
                  className="flex items-center space-x-1 px-3 py-2 text-sm text-gray-700 hover:text-red-600 transition-colors"
                >
                  <LogOut className="w-4 h-4" />
                  <span>Disconnect</span>
                </button>
              </div>
            ) : (
              <button
                onClick={connect}
                className="flex items-center space-x-2 bg-primary-600 text-white px-4 py-2 rounded-lg hover:bg-primary-700 transition-colors shadow-md"
              >
                <Wallet className="w-4 h-4" />
                <span>Connect Wallet</span>
              </button>
            )}
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
