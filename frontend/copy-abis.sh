#!/bin/bash

# Script to copy contract ABIs from forge build output to frontend

echo "Copying contract ABIs..."

# Create abis directory
mkdir -p public/abis

# Copy ABIs from out directory
if [ -d "../out" ]; then
    echo "Found forge build output, copying ABIs..."
    
    # Copy each contract ABI
    cp ../out/ConsumerInterface.sol/ConsumerInterface.json public/abis/ 2>/dev/null && echo "✓ ConsumerInterface"
    cp ../out/AgricultureSupplyChain.sol/AgricultureSupplyChain.json public/abis/ 2>/dev/null && echo "✓ AgricultureSupplyChain"
    cp ../out/QRCodeRegistry.sol/QRCodeRegistry.json public/abis/ 2>/dev/null && echo "✓ QRCodeRegistry"
    cp ../out/PaymentContract.sol/PaymentContract.json public/abis/ 2>/dev/null && echo "✓ PaymentContract"
    cp ../out/FairPricingContract.sol/FairPricingContract.json public/abis/ 2>/dev/null && echo "✓ FairPricingContract"
    cp ../out/FraudDetectionContract.sol/FraudDetectionContract.json public/abis/ 2>/dev/null && echo "✓ FraudDetectionContract"
    
    echo ""
    echo "ABIs copied successfully!"
    echo "Note: If some contracts show errors, run 'forge build' first in the root directory"
else
    echo "Error: ../out directory not found"
    echo "Please run 'forge build' in the root directory first"
    exit 1
fi
