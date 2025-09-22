
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {FairPricingContract} from "../src/FairPricingContract.sol";
import {AgricultureSupplyChain} from "../src/AgricultureSupplyChain.sol";
import {PaymentContract} from "../src/PaymentContract.sol";

contract FairPricingContractTest is Test {
    FairPricingContract public fairPricing;
    AgricultureSupplyChain public supplyChain;
    PaymentContract public payment;

    address public admin = address(this);
    address public farmer1 = address(0x123);
    address public farmer2 = address(0x456);
    address public oracle = address(0x789);

    uint128 public constant DEFAULT_MIN_PRICE = 1 ether;
    uint32 public constant MAX_VOLATILITY = 2000; // 20%

    event FarmerRegistered(address indexed farmer, uint256 timestamp);
    event PriceValidated(uint256 indexed productId, uint256 validatedPrice, address indexed farmer);
    event FarmerRated(address indexed farmer, uint256 newRating, address indexed rater);
    event PriceViolationDetected(uint256 indexed productId, uint256 attemptedPrice, uint256 minimumRequired);

    function setUp() public {
        // Deploy dependencies first
        supplyChain = new AgricultureSupplyChain();
        payment = new PaymentContract();

        // Deploy fair pricing contract
        fairPricing = new FairPricingContract(
            address(supplyChain),
            address(payment),
            oracle
        );

        // Setup roles in supply chain
        supplyChain.grantFarmerRole(farmer1);
        supplyChain.grantFarmerRole(farmer2);

        // Fund test accounts
        vm.deal(farmer1, 10 ether);
        vm.deal(farmer2, 10 ether);
    }

    function testInitialSetup() public {
        assertEq(address(fairPricing.supplyChainContract()), address(supplyChain));
        assertEq(address(fairPricing.paymentContract()), address(payment));
        assertEq(fairPricing.globalMinimumPrice(), DEFAULT_MIN_PRICE);
        assertEq(fairPricing.maxVolatilityThreshold(), MAX_VOLATILITY);
    }

    function testRegisterFarmer() public {
        vm.expectEmit(true, false, false, true);
        emit FarmerRegistered(farmer1, block.timestamp);

        bool success = fairPricing.registerFarmer(farmer1);
        assertTrue(success);

        (
            uint16 currentRating,
            uint32 totalTransactions,
            uint32 penaltyCount,
            bool isActive,
            uint64 lastActivity
        ) = fairPricing.getFarmerProfile(farmer1);

        assertEq(currentRating, 500); // 5.0 rating (MAX_RATING / 10)
        assertEq(totalTransactions, 0);
        assertEq(penaltyCount, 0);
        assertTrue(isActive);
        assertEq(lastActivity, block.timestamp);
    }

    function testRegisterFarmerOnlyAdmin() public {
        vm.prank(farmer1);
        vm.expectRevert();
        fairPricing.registerFarmer(farmer2);
    }

    function testValidateProductPricing() public {
        // Register farmer first
        fairPricing.registerFarmer(farmer1);

        // Create a product in supply chain
        vm.prank(farmer1);
        uint256 productId = supplyChain.createProduct(
            100, 
            uint96(1.5 ether), 
            bytes32("location"), 
            new string[](0)
        );

        vm.expectEmit(true, true, false, true);
        emit PriceValidated(productId, 1.5 ether, farmer1);

        // Validate pricing (should pass as it's above minimum)
        bool success = fairPricing.validateProductPricing(productId, 1.5 ether, farmer1);
        assertTrue(success);

        // Check farmer activity was updated
        (,uint32 totalTransactions,,,) = fairPricing.getFarmerProfile(farmer1);
        assertEq(totalTransactions, 1);
    }

    function testValidatePricingBelowMinimum() public {
        fairPricing.registerFarmer(farmer1);

        vm.prank(farmer1);
        uint256 productId = supplyChain.createProduct(
            100, 
            uint96(0.5 ether), 
            bytes32("location"), 
            new string[](0)
        );

        vm.expectEmit(true, false, false, true);
        emit PriceViolationDetected(productId, 0.5 ether, DEFAULT_MIN_PRICE);

        vm.expectRevert(FairPricingContract.InsufficientPrice.selector);
        fairPricing.validateProductPricing(productId, 0.5 ether, farmer1);
    }

    function testUnregisteredFarmerValidation() public {
        vm.prank(farmer1);
        uint256 productId = supplyChain.createProduct(
            100, 
            uint96(1.5 ether), 
            bytes32("location"), 
            new string[](0)
        );

        vm.expectRevert(FairPricingContract.FarmerNotRegistered.selector);
        fairPricing.validateProductPricing(productId, 1.5 ether, farmer1);
    }

    function testRateFarmer() public {
        fairPricing.registerFarmer(farmer1);

        vm.expectEmit(true, false, false, true);
        emit FarmerRated(farmer1, 400, admin); // Rating will be averaged

        fairPricing.rateFarmer(farmer1, 300, "Good performance");

        (uint16 currentRating,,,,) = fairPricing.getFarmerProfile(farmer1);
        assertEq(currentRating, 400); // (500 + 300) / 2
    }

    function testRateFarmerInvalidRating() public {
        fairPricing.registerFarmer(farmer1);

        vm.expectRevert(FairPricingContract.InvalidRating.selector);
        fairPricing.rateFarmer(farmer1, 6000, "Invalid rating"); // MAX_RATING is 5000
    }

    function testFarmerSuspensionAfterPoorRatings() public {
        fairPricing.registerFarmer(farmer1);

        // Give 5 poor ratings (below 12.5/50)
        for (uint i = 0; i < 5; i++) {
            fairPricing.rateFarmer(farmer1, 100, "Poor performance");
        }

        (,,, bool isActive,) = fairPricing.getFarmerProfile(farmer1);
        assertFalse(isActive); // Should be suspended
    }

    function testIsPriceValid() public {
        fairPricing.registerFarmer(farmer1);

        assertTrue(fairPricing.isPriceValid(1, 1.5 ether, farmer1));
        assertFalse(fairPricing.isPriceValid(1, 0.5 ether, farmer1));
        assertFalse(fairPricing.isPriceValid(1, 1.5 ether, farmer2)); // Unregistered farmer
    }

    function testUpdateMinimumPrice() public {
        vm.prank(oracle);
        fairPricing.updateMinimumPrice(1, 2 ether);

        // Price validation should now use the product-specific minimum
        fairPricing.registerFarmer(farmer1);

        vm.prank(farmer1);
        uint256 productId = supplyChain.createProduct(
            100, 
            uint96(2.5 ether), 
            bytes32("location"), 
            new string[](0)
        );

        assertTrue(fairPricing.validateProductPricing(productId, 2.5 ether, farmer1));

        vm.expectRevert(FairPricingContract.InsufficientPrice.selector);
        fairPricing.validateProductPricing(productId, 1.5 ether, farmer1);
    }

    function testUpdateMinimumPriceOnlyOracle() public {
        vm.prank(farmer1);
        vm.expectRevert();
        fairPricing.updateMinimumPrice(1, 2 ether);
    }

    function testUpdateGlobalMinimumPrice() public {
        fairPricing.updateGlobalMinimumPrice(2 ether);
        assertEq(fairPricing.globalMinimumPrice(), 2 ether);
    }

    function testPauseUnpause() public {
        fairPricing.pause();

        fairPricing.registerFarmer(farmer1);
        vm.expectRevert("Pausable: paused");
        fairPricing.validateProductPricing(1, 1 ether, farmer1);

        fairPricing.unpause();
        // Should work again after unpause
    }

    function testFarmerRatingBonus() public {
        fairPricing.registerFarmer(farmer1);
        fairPricing.registerFarmer(farmer2);

        // Give farmer1 excellent ratings
        for (uint i = 0; i < 5; i++) {
            fairPricing.rateFarmer(farmer1, 4900, "Excellent");
        }

        vm.prank(farmer1);
        uint256 productId1 = supplyChain.createProduct(100, uint96(1 ether), bytes32("loc1"), new string[](0));

        vm.prank(farmer2);
        uint256 productId2 = supplyChain.createProduct(100, uint96(1 ether), bytes32("loc2"), new string[](0));

        // Both should validate the same price, but farmer1 gets bonus calculation internally
        assertTrue(fairPricing.validateProductPricing(productId1, 1 ether, farmer1));
        assertTrue(fairPricing.validateProductPricing(productId2, 1 ether, farmer2));
    }

    function testReactivateFarmer() public {
        fairPricing.registerFarmer(farmer1);

        // Suspend farmer through poor ratings
        for (uint i = 0; i < 5; i++) {
            fairPricing.rateFarmer(farmer1, 100, "Poor");
        }

        (,,, bool isActive,) = fairPricing.getFarmerProfile(farmer1);
        assertFalse(isActive);

        // Reactivate by registering again
        fairPricing.registerFarmer(farmer1);
        (,,, isActive,) = fairPricing.getFarmerProfile(farmer1);
        assertTrue(isActive);
    }

    function testFarmerTransactionHistory() public {
        fairPricing.registerFarmer(farmer1);

        // Create multiple products
        vm.startPrank(farmer1);
        uint256 productId1 = supplyChain.createProduct(100, uint96(1.1 ether), bytes32("loc1"), new string[](0));
        uint256 productId2 = supplyChain.createProduct(200, uint96(1.2 ether), bytes32("loc2"), new string[](0));
        vm.stopPrank();

        fairPricing.validateProductPricing(productId1, 1.1 ether, farmer1);
        fairPricing.validateProductPricing(productId2, 1.2 ether, farmer1);

        (,uint32 totalTransactions,,,) = fairPricing.getFarmerProfile(farmer1);
        assertEq(totalTransactions, 2);
    }

    receive() external payable {}
}
