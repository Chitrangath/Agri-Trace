import React from 'react';
import { Link } from 'react-router-dom';
import { Sprout, Shield, QrCode, TrendingUp, Users, CheckCircle } from 'lucide-react';

const Home = () => {
  const features = [
    {
      icon: <Shield className="w-8 h-8" />,
      title: 'Product Verification',
      description: 'Verify the authenticity and origin of agricultural products',
      link: '/verify',
    },
    {
      icon: <QrCode className="w-8 h-8" />,
      title: 'QR Code Scanning',
      description: 'Scan QR codes to instantly access product information',
      link: '/qr-scan',
    },
    {
      icon: <TrendingUp className="w-8 h-8" />,
      title: 'Supply Chain Tracking',
      description: 'Track products through every stage from farm to consumer',
      link: '/verify',
    },
    {
      icon: <Users className="w-8 h-8" />,
      title: 'Farmer Dashboard',
      description: 'Manage your products and track your supply chain',
      link: '/farmer',
    },
  ];

  const benefits = [
    'End-to-end traceability',
    'Fair pricing protection',
    'Fraud detection',
    'Quality monitoring',
    'Consumer transparency',
    'Blockchain security',
  ];

  return (
    <div className="fade-in">
      {/* Hero Section */}
      <div className="text-center mb-16">
        <div className="flex justify-center mb-6">
          <Sprout className="w-20 h-20 text-primary-700" />
        </div>
        <h1 className="text-5xl font-bold text-gray-900 mb-4">
          Agri-Trace
        </h1>
        <p className="text-xl text-gray-600 mb-8 max-w-2xl mx-auto">
          Blockchain-powered supply chain traceability for agricultural products.
          From farm to consumer, every step is transparent and verifiable.
        </p>
        <div className="flex justify-center space-x-4">
          <Link
            to="/verify"
            className="btn-primary text-lg px-8 py-3"
          >
            Verify a Product
          </Link>
          <Link
            to="/farmer"
            className="btn-secondary text-lg px-8 py-3"
          >
            Farmer Portal
          </Link>
        </div>
      </div>

      {/* Features Grid */}
      <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6 mb-16">
        {features.map((feature, index) => (
          <Link
            key={index}
            to={feature.link}
            className="card hover:scale-105 transition-transform cursor-pointer"
          >
            <div className="text-primary-700 mb-4">{feature.icon}</div>
            <h3 className="text-xl font-semibold text-gray-800 mb-2">
              {feature.title}
            </h3>
            <p className="text-gray-600">{feature.description}</p>
          </Link>
        ))}
      </div>

      {/* Benefits Section */}
      <div className="bg-white/80 backdrop-blur-sm rounded-lg shadow-lg p-8 mb-16 border border-earth-200">
        <h2 className="text-3xl font-bold text-gray-900 mb-6 text-center">
          Why Choose Agri-Trace?
        </h2>
        <div className="grid md:grid-cols-3 gap-4">
          {benefits.map((benefit, index) => (
            <div key={index} className="flex items-center space-x-3">
              <CheckCircle className="w-5 h-5 text-green-500 flex-shrink-0" />
              <span className="text-gray-700">{benefit}</span>
            </div>
          ))}
        </div>
      </div>

      {/* How It Works */}
      <div className="bg-gradient-to-r from-primary-100 via-earth-100 to-secondary-100 rounded-lg p-8 border border-earth-200 shadow-md">
        <h2 className="text-3xl font-bold text-gray-900 mb-6 text-center">
          How It Works
        </h2>
        <div className="grid md:grid-cols-4 gap-6">
          <div className="text-center">
            <div className="w-12 h-12 bg-primary-600 text-white rounded-full flex items-center justify-center mx-auto mb-4 text-xl font-bold shadow-md">
              1
            </div>
            <h3 className="font-semibold mb-2">Farm Registration</h3>
            <p className="text-sm text-gray-600">Farmers register products on the blockchain</p>
          </div>
          <div className="text-center">
            <div className="w-12 h-12 bg-primary-600 text-white rounded-full flex items-center justify-center mx-auto mb-4 text-xl font-bold shadow-md">
              2
            </div>
            <h3 className="font-semibold mb-2">Supply Chain Tracking</h3>
            <p className="text-sm text-gray-600">Products tracked through each stage</p>
          </div>
          <div className="text-center">
            <div className="w-12 h-12 bg-primary-600 text-white rounded-full flex items-center justify-center mx-auto mb-4 text-xl font-bold shadow-md">
              3
            </div>
            <h3 className="font-semibold mb-2">QR Code Generation</h3>
            <p className="text-sm text-gray-600">Unique QR codes for each product</p>
          </div>
          <div className="text-center">
            <div className="w-12 h-12 bg-primary-600 text-white rounded-full flex items-center justify-center mx-auto mb-4 text-xl font-bold shadow-md">
              4
            </div>
            <h3 className="font-semibold mb-2">Consumer Verification</h3>
            <p className="text-sm text-gray-600">Consumers verify authenticity instantly</p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Home;
