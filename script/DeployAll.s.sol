
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {AgricultureSupplyChain} from "../src/AgricultureSupplyChain.sol";
import {PaymentContract} from "../src/PaymentContract.sol";
import {QRCodeRegistry} from "../src/QRCodeRegistry.sol";
import {FairPricingContract} from "../src/FairPricingContract.sol";
import {ConsumerInterface} from "../src/ConsumerInterface.sol";
import {FraudDetectionContract} from "../src/FraudDetectionContract.sol";

contract DeployAll is Script {
    struct DeployedContracts {
        AgricultureSupplyChain supplyChain;
        PaymentContract payment;
        QRCodeRegistry qrRegistry;
        FairPricingContract fairPricing;
        ConsumerInterface consumerInterface;
        FraudDetectionContract fraudDetection;
    }

    function run() external returns (DeployedContracts memory) {
        address deployer = msg.sender;
        console.log("Deploying all contracts...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast();

        // 1. Deploy existing core contracts first
        console.log("\n=== DEPLOYING CORE CONTRACTS ===");

        AgricultureSupplyChain supplyChain = new AgricultureSupplyChain();
        console.log("AgricultureSupplyChain deployed at:", address(supplyChain));

        PaymentContract payment = new PaymentContract();
        console.log("PaymentContract deployed at:", address(payment));

        QRCodeRegistry qrRegistry = new QRCodeRegistry();
        console.log("QRCodeRegistry deployed at:", address(qrRegistry));

        // 2. Deploy enhanced contracts (order matters due to dependencies)
        console.log("\n=== DEPLOYING ENHANCED CONTRACTS ===");

        // FairPricingContract needs supplyChain and payment addresses
        FairPricingContract fairPricing = new FairPricingContract(
            address(supplyChain),
            address(payment),
            deployer // Use deployer as initial oracle
        );
        console.log("FairPricingContract deployed at:", address(fairPricing));

        // ConsumerInterface (no constructor dependencies)
        ConsumerInterface consumerInterface = new ConsumerInterface();
        console.log("ConsumerInterface deployed at:", address(consumerInterface));

        // FraudDetectionContract needs supplyChain address
        FraudDetectionContract fraudDetection = new FraudDetectionContract(
            address(supplyChain)
        );
        console.log("FraudDetectionContract deployed at:", address(fraudDetection));

        // 3. Configure integrations
        console.log("\n=== CONFIGURING INTEGRATIONS ===");

        // Configure ConsumerInterface to connect all contracts
        consumerInterface.configureContracts(
            address(supplyChain),
            address(qrRegistry), 
            address(fairPricing)
        );
        console.log("ConsumerInterface configured with all dependencies");

        // Set up initial fair pricing configuration
        fairPricing.updateGlobalMinimumPrice(1 ether); // 1 ETH minimum support price
        console.log("Global minimum price set to 1 ETH");

        // 4. Set up sample farmer and test data
        console.log("\n=== INITIAL SETUP ===");

        // Grant deployer farmer role for testing
        supplyChain.grantFarmerRole(deployer);
        fairPricing.registerFarmer(deployer);
        console.log("Deployer registered as farmer for testing");

        // Set up sample metadata
        consumerInterface.setFarmerName(deployer, "Demo Farm");
        console.log("Sample farmer metadata configured");

        vm.stopBroadcast();

        // 5. Verification and summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log(" AgricultureSupplyChain:", address(supplyChain));
        console.log(" PaymentContract:", address(payment));
        console.log(" QRCodeRegistry:", address(qrRegistry));
        console.log(" FairPricingContract:", address(fairPricing));
        console.log(" ConsumerInterface:", address(consumerInterface));
        console.log(" FraudDetectionContract:", address(fraudDetection));

        console.log("\n=== INTEGRATION STATUS ===");
        console.log("Fair Pricing => Supply Chain: CONNECTED");
        console.log("Fair Pricing => Payment: CONNECTED");
        console.log("Consumer Interface => All Contracts: CONNECTED");
        console.log("Fraud Detection => Supply Chain: CONNECTED");

        console.log("\n=== NEXT STEPS ===");
        console.log("1. Register additional farmers: fairPricing.registerFarmer(address)");
        console.log("2. Set product names: consumerInterface.setProductName(id, name)");
        console.log("3. Configure additional oracles: fairPricing.grantRole(PRICE_ORACLE_ROLE, oracle)");
        console.log("4. Add fraud analysts: fraudDetection.grantRole(FRAUD_ANALYST_ROLE, analyst)");

        // Save deployment addresses to file
        _saveDeploymentInfo(
            address(supplyChain),
            address(payment),
            address(qrRegistry),
            address(fairPricing),
            address(consumerInterface),
            address(fraudDetection)
        );

        return DeployedContracts({
            supplyChain: supplyChain,
            payment: payment,
            qrRegistry: qrRegistry,
            fairPricing: fairPricing,
            consumerInterface: consumerInterface,
            fraudDetection: fraudDetection
        });
    }

    function _saveDeploymentInfo(
        address supplyChain,
        address payment,
        address qrRegistry,
        address fairPricing,
        address consumerInterface,
        address fraudDetection
    ) internal {
        string memory deploymentInfo = string(abi.encodePacked(
            "# Farm-to-Consumer Traceability Contract Addresses\n",
            "# Generated on deployment\n\n",
            "# Core Contracts\n",
            "SUPPLY_CHAIN_ADDRESS=", vm.toString(supplyChain), "\n",
            "PAYMENT_ADDRESS=", vm.toString(payment), "\n",
            "QR_REGISTRY_ADDRESS=", vm.toString(qrRegistry), "\n\n",
            "# Enhanced Contracts\n",
            "FAIR_PRICING_ADDRESS=", vm.toString(fairPricing), "\n",
            "CONSUMER_INTERFACE_ADDRESS=", vm.toString(consumerInterface), "\n",
            "FRAUD_DETECTION_ADDRESS=", vm.toString(fraudDetection), "\n\n",
            "# Integration Status: ALL CONNECTED\n"
        ));

        vm.writeFile("deployments/all-contracts.env", deploymentInfo);
        console.log("\nDeployment addresses saved to: deployments/all-contracts.env");
    }
}
