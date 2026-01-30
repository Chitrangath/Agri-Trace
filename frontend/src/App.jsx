import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { Web3Provider } from './contexts/Web3Context';
import Navbar from './components/Navbar';
import Home from './components/Home';
import VerifyProduct from './components/VerifyProduct';
import QRScan from './components/QRScan';
import FarmerDashboard from './components/FarmerDashboard';
import ProductDetails from './components/ProductDetails';
import './App.css';

function App() {
  return (
    <Web3Provider>
      <Router>
        <div className="min-h-screen bg-gradient-to-br from-primary-50 via-earth-50 to-secondary-50">
          <Navbar />
          <main className="container mx-auto px-4 py-8">
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/verify" element={<VerifyProduct />} />
              <Route path="/qr-scan" element={<QRScan />} />
              <Route path="/farmer" element={<FarmerDashboard />} />
              <Route path="/product/:id" element={<ProductDetails />} />
            </Routes>
          </main>
          <Toaster position="top-right" />
        </div>
      </Router>
    </Web3Provider>
  );
}

export default App;
