
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ConsumerInterface} from "../src/ConsumerInterface.sol";
import {AgricultureSupplyChain} from "../src/AgricultureSupplyChain.sol";
import {QRCodeRegistry} from "../src/QRCodeRegistry.sol";
import {FairPricingContract} from "../src/FairPricingContract.sol";
import {PaymentContract} from "../src/PaymentContract.sol";

contract ConsumerInterfaceTest is Test {
    ConsumerInterface public consumer;
    AgricultureSupplyChain public supplyChain;
    QRCodeRegistry public qrRegistry;
    FairPricingContract public fairPricing;
    PaymentContract public payment;

    address public admin = address(this);
    address public farmer1 = address(0x123);
    address public consumer1 = address(0x456);
    address public consumer2 = address(0x789);

    uint256 public productId1;
    uint256 public productId2;
    bytes32 public qrHash1 = keccak256("QR1");
    bytes32 public qrHash2 = keccak256("QR2");

    event ProductVerified(uint256 indexed productId, address indexed consumer, uint256 timestamp);
    event QRCodeScanned(bytes32 indexed qrHash, address indexed consumer, bool isValid);

    function setUp() public {
        // Deploy all contracts
        supplyChain = new AgricultureSupplyChain();
        payment = new PaymentContract();
        qrRegistry = new QRCodeRegistry();
        fairPricing = new FairPricingContract(address(supplyChain), address(payment), admin);
        consumer = new ConsumerInterface();

        // Configure consumer interface
        consumer.configureContracts(
            address(supplyChain),
            address(qrRegistry),
            address(fairPricing)
        );

        // Setup roles
        supplyChain.grantFarmerRole(farmer1);
        fairPricing.registerFarmer(farmer1);

        // Create test products
        vm.startPrank(farmer1);
        productId1 = supplyChain.createProduct(
            100,
            uint96(1.5 ether),
            bytes32("farm_location_1"),
            new string[](0)
        );
        productId2 = supplyChain.createProduct(
            200,
            uint96(2.0 ether),
            bytes32("farm_location_2"),
            new string[](0)
        );
        vm.stopPrank();

        // Register QR codes
        qrRegistry.registerQRCode(qrHash1, uint32(productId1), "ipfs_metadata_1");
        qrRegistry.registerQRCode(qrHash2, uint32(productId2), "ipfs_metadata_2");

        // Add product quality data
        supplyChain.addQualityData(
            productId1,
            25, // temperature
            60, // humidity  
            850, // quality score
            bytes32("cert_hash"),
            "quality_ipfs_hash"
        );

        // Set up consumer-friendly metadata
        consumer.setProductName(productId1, "Organic Tomatoes");
        consumer.setProductName(productId2, "Fresh Carrots");
        consumer.setFarmerName(farmer1, "Green Valley Farm");
        consumer.addProductCertification(productId1, "USDA Organic");
        consumer.addProductCertification(productId1, "Fair Trade");

        // Fund test accounts
        vm.deal(consumer1, 1 ether);
        vm.deal(consumer2, 1 ether);
    }

    function testContractConfiguration() public {
        assertEq(address(consumer.supplyChainContract()), address(supplyChain));
        assertEq(address(consumer.qrCodeRegistry()), address(qrRegistry));
        assertEq(address(consumer.pricingContract()), address(fairPricing));
    }

    function testConfigureContractsOnlyAdmin() public {
        vm.prank(consumer1);
        vm.expectRevert();
        consumer.configureContracts(address(0), address(0), address(0));
    }

    function testVerifyProduct() public {
        vm.prank(consumer1);
        vm.expectEmit(true, true, false, true);
        emit ProductVerified(productId1, consumer1, block.timestamp);

        ConsumerInterface.ProductSummary memory summary = consumer.verifyProduct(productId1);

        assertEq(summary.productId, productId1);
        assertEq(summary.farmer, farmer1);
        assertEq(summary.currentPrice, 1.5 ether);
        assertEq(summary.quantity, 100);
        assertEq(summary.currentStage, 0); // Planted
        assertTrue(summary.isAuthentic);
        assertGt(summary.qualityScore, 0);

        // Check consumer history was updated
        uint256[] memory history = consumer.getConsumerHistory(consumer1);
        assertEq(history.length, 1);
        assertEq(history[0], productId1);

        // Check product views were incremented
        (uint256 views,) = consumer.getProductMetrics(productId1);
        assertEq(views, 1);

        // Check total verifications
        assertEq(consumer.totalVerifications(), 1);
    }

    function testVerifyProductNotFound() public {
        vm.prank(consumer1);
        vm.expectRevert(ConsumerInterface.ProductNotFound.selector);
        consumer.verifyProduct(999); // Non-existent product
    }

    function testVerifyByQRCode() public {
        vm.prank(consumer1);
        vm.expectEmit(true, true, false, true);
        emit QRCodeScanned(qrHash1, consumer1, true);

        ConsumerInterface.VerificationResult memory result = consumer.verifyByQRCode(qrHash1);

        assertTrue(result.isValid);
        assertEq(result.productId, productId1);
        assertEq(result.farmerName, "Green Valley Farm");
        assertEq(result.status, "Planted");
        assertGt(result.rating, 0); // Should have some rating
    }

    function testVerifyByInvalidQRCode() public {
        bytes32 invalidQR = keccak256("INVALID");

        vm.prank(consumer1);
        vm.expectEmit(true, true, false, true);
        emit QRCodeScanned(invalidQR, consumer1, false);

        ConsumerInterface.VerificationResult memory result = consumer.verifyByQRCode(invalidQR);

        assertFalse(result.isValid);
        assertEq(result.productId, 0);
        assertEq(result.farmerName, "");
        assertEq(result.rating, 0);
        assertTrue(bytes(result.status).length > 0); // Should have error message
    }

    function testGetFarmerReputation() public {
        // Rate the farmer a few times
        fairPricing.rateFarmer(farmer1, 4500, "Excellent quality");
        fairPricing.rateFarmer(farmer1, 4000, "Good service");

        ConsumerInterface.FarmerReputation memory reputation = consumer.getFarmerReputation(farmer1);

        assertEq(reputation.farmerAddress, farmer1);
        assertGt(reputation.trustScore, 0);
        assertGt(reputation.totalSales, 0);
        assertTrue(reputation.isVerified);
    }

    function testGetProductJourney() public {
        // Update product stage
        vm.prank(farmer1);
        supplyChain.updateProductStage(productId1, AgricultureSupplyChain.ProductStage.Harvested);

        (
            string[] memory stages,
            uint256[] memory timestamps,
            uint256[] memory qualityScores
        ) = consumer.getProductJourney(productId1);

        assertEq(stages.length, 3); // Planted, Growing, Harvested
        assertEq(timestamps.length, 3);
        assertEq(qualityScores.length, 3);
        assertEq(stages[0], "Planted");
        assertEq(stages[1], "Growing");
        assertEq(stages[2], "Harvested");
    }

    function testBatchVerifyProducts() public {
        uint256[] memory productIds = new uint256[](2);
        productIds[0] = productId1;
        productIds[1] = productId2;

        vm.prank(consumer1);
        ConsumerInterface.ProductSummary[] memory summaries = consumer.batchVerifyProducts(productIds);

        assertEq(summaries.length, 2);
        assertEq(summaries[0].productId, productId1);
        assertEq(summaries[1].productId, productId2);
        assertEq(summaries[0].farmer, farmer1);
        assertEq(summaries[1].farmer, farmer1);
    }

    function testBatchVerifyWithInvalidProduct() public {
        uint256[] memory productIds = new uint256[](3);
        productIds[0] = productId1;
        productIds[1] = 999; // Invalid product
        productIds[2] = productId2;

        vm.prank(consumer1);
        ConsumerInterface.ProductSummary[] memory summaries = consumer.batchVerifyProducts(productIds);

        assertEq(summaries.length, 3);
        assertEq(summaries[0].productId, productId1); // Valid
        assertEq(summaries[1].productId, 0); // Invalid - default
        assertEq(summaries[2].productId, productId2); // Valid
    }

    function testGetConsumerHistory() public {
        // Consumer verifies multiple products
        vm.startPrank(consumer1);
        consumer.verifyProduct(productId1);
        consumer.verifyProduct(productId2);
        consumer.verifyProduct(productId1); // Verify same product again
        vm.stopPrank();

        uint256[] memory history = consumer.getConsumerHistory(consumer1);
        assertEq(history.length, 3);
        assertEq(history[0], productId1);
        assertEq(history[1], productId2);
        assertEq(history[2], productId1);
    }

    function testGetProductMetrics() public {
        // Multiple consumers verify the same product
        vm.prank(consumer1);
        consumer.verifyProduct(productId1);
        vm.prank(consumer2);
        consumer.verifyProduct(productId1);

        (uint256 views, string[] memory certifications) = consumer.getProductMetrics(productId1);

        assertEq(views, 2);
        assertEq(certifications.length, 2);
        assertEq(certifications[0], "USDA Organic");
        assertEq(certifications[1], "Fair Trade");
    }

    function testSetProductName() public {
        consumer.setProductName(productId1, "Premium Organic Tomatoes");
        assertEq(consumer.productNames(productId1), "Premium Organic Tomatoes");
    }

    function testSetProductNameOnlyAdmin() public {
        vm.prank(consumer1);
        vm.expectRevert();
        consumer.setProductName(productId1, "Unauthorized Name");
    }

    function testSetFarmerName() public {
        consumer.setFarmerName(farmer1, "Sunrise Organic Farm");
        assertEq(consumer.farmerNames(farmer1), "Sunrise Organic Farm");
    }

    function testSetFarmerNameOnlyAdmin() public {
        vm.prank(consumer1);
        vm.expectRevert();
        consumer.setFarmerName(farmer1, "Unauthorized Name");
    }

    function testAddProductCertification() public {
        consumer.addProductCertification(productId1, "Non-GMO Project Verified");

        (,string[] memory certifications) = consumer.getProductMetrics(productId1);
        assertEq(certifications.length, 3); // Original 2 + new 1
        assertEq(certifications[2], "Non-GMO Project Verified");
    }

    function testAddProductCertificationOnlyAdmin() public {
        vm.prank(consumer1);
        vm.expectRevert();
        consumer.addProductCertification(productId1, "Unauthorized Cert");
    }

    function testContractsNotConfigured() public {
        // Deploy new consumer interface without configuration
        ConsumerInterface unconfiguredConsumer = new ConsumerInterface();

        vm.expectRevert(ConsumerInterface.ContractNotConfigured.selector);
        unconfiguredConsumer.verifyProduct(productId1);
    }

    function testMultipleConsumersTracking() public {
        // Multiple consumers verify different products
        vm.prank(consumer1);
        consumer.verifyProduct(productId1);

        vm.prank(consumer2);
        consumer.verifyProduct(productId2);

        vm.prank(consumer1);
        consumer.verifyProduct(productId2);

        // Check individual histories
        uint256[] memory history1 = consumer.getConsumerHistory(consumer1);
        uint256[] memory history2 = consumer.getConsumerHistory(consumer2);

        assertEq(history1.length, 2);
        assertEq(history2.length, 1);
        assertEq(history1[0], productId1);
        assertEq(history1[1], productId2);
        assertEq(history2[0], productId2);

        // Check total verifications
        assertEq(consumer.totalVerifications(), 3);
    }

    function testProductJourneyWithInvalidProduct() public {
        vm.expectRevert(ConsumerInterface.ProductNotFound.selector);
        consumer.getProductJourney(999);
    }

    function testVerificationWithQualityData() public {
        vm.prank(consumer1);
        ConsumerInterface.ProductSummary memory summary = consumer.verifyProduct(productId1);

        // Should have quality score from the quality data we added
        assertEq(summary.qualityScore, 850);
    }

    function testStageTextConversion() public {
        // Test different stages
        vm.prank(farmer1);
        supplyChain.updateProductStage(productId1, AgricultureSupplyChain.ProductStage.InTransit);

        vm.prank(consumer1);
        ConsumerInterface.VerificationResult memory result = consumer.verifyByQRCode(qrHash1);

        assertEq(result.status, "In Transit");
    }

    receive() external payable {}
}
