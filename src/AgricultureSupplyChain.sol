// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import "forge-std/Test.sol";

contract AgricultureSupplyChainTest is Test {
    AgricultureSupplyChain supplyChain;
    address farmer = address(0x1);
    address distributor = address(0x2);
    address retailer = address(0x3);
    address admin;

    function setUp() public {
        admin = address(this);
        supplyChain = new AgricultureSupplyChain();
        supplyChain.grantFarmerRole(farmer);
        supplyChain.grantDistributorRole(distributor);
        supplyChain.grantRetailerRole(retailer);
    }

    function testCreateProductWithIPFS() public {
        vm.prank(farmer);
        string[] memory ipfsHashes = new string[](2);
        ipfsHashes[0] = "QmTestHash1";
        ipfsHashes[1] = "QmTestHash2";
        
        uint256 id = supplyChain.createProduct(100, 500, bytes32("farmLocation"), ipfsHashes);
        
        // Fixed: getProduct returns 6 values, not 7
        (, , uint32 quantity, uint96 price, address owner, AgricultureSupplyChain.ProductStage stage) = supplyChain.getProduct(id);
        
        // Get IPFS hashes separately
        string[] memory hashes = supplyChain.getProductIPFSHashes(id);
        
        assertEq(owner, farmer);
        assertEq(quantity, 100);
        assertEq(price, 500);
        assertEq(uint8(stage), uint8(AgricultureSupplyChain.ProductStage.Planted));
        assertEq(hashes.length, 2);
        assertEq(hashes[0], "QmTestHash1");
        assertEq(hashes[1], "QmTestHash2");
    }

    function testAddProductIPFSHash() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(50, 200, bytes32("loc"), new string[](0));
        
        vm.prank(farmer);
        supplyChain.addProductIPFSHash(id, "QmNewHash");
        
        string[] memory hashes = supplyChain.getProductIPFSHashes(id);
        assertEq(hashes.length, 1);
        assertEq(hashes[0], "QmNewHash");
    }

    function testAddQualityDataWithIPFS() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(10, 150, bytes32("loc"), new string[](0));
        
        vm.prank(farmer);
        supplyChain.addQualityData(id, 25, 50, 90, bytes32(0), "QmQualityHash");
        
        (AgricultureSupplyChain.QualityData[] memory qualities, string[] memory ipfsHashes) = supplyChain.getQualityHistory(id);
        
        assertEq(qualities.length, 1);
        assertEq(qualities[0].qualityScore, 90);
        assertEq(qualities[0].temperature, 25);
        assertEq(qualities[0].humidity, 50);
        assertEq(ipfsHashes.length, 1);
        assertEq(ipfsHashes[0], "QmQualityHash");
    }

    function testUpdateProductStage() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(100, 500, bytes32("loc"), new string[](0));
        
        vm.prank(farmer);
        supplyChain.updateProductStage(id, AgricultureSupplyChain.ProductStage.Growing);
        
        // Fixed: getProduct returns 6 values, not 7
        (, , , , , AgricultureSupplyChain.ProductStage stage) = supplyChain.getProduct(id);
        assertEq(uint8(stage), uint8(AgricultureSupplyChain.ProductStage.Growing));
    }

    function testTransferOwnership() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(100, 500, bytes32("loc"), new string[](0));
        
        vm.prank(farmer);
        supplyChain.transferOwnership(id, distributor, 600);
        
        // Fixed: getProduct returns 6 values, not 7
        (, , , uint96 price, address owner, ) = supplyChain.getProduct(id);
        assertEq(owner, distributor);
        assertEq(price, 600);
    }

    function testFailCreateProductWithZeroQuantity() public {
        vm.prank(farmer);
        supplyChain.createProduct(0, 500, bytes32("loc"), new string[](0));
    }

    function testFailCreateProductWithZeroPrice() public {
        vm.prank(farmer);
        supplyChain.createProduct(100, 0, bytes32("loc"), new string[](0));
    }

    function testFailUnauthorizedStageUpdate() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(100, 500, bytes32("loc"), new string[](0));
        
        // Retailer trying to update to Growing stage (only farmers can do this)
        vm.prank(retailer);
        supplyChain.updateProductStage(id, AgricultureSupplyChain.ProductStage.Growing);
    }

    function testFailTransferToZeroAddress() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(100, 500, bytes32("loc"), new string[](0));
        
        vm.prank(farmer);
        supplyChain.transferOwnership(id, address(0), 600);
    }

    function testFailExceedMaxIPFSHashes() public {
        vm.prank(farmer);
        string[] memory ipfsHashes = new string[](51); // Exceeds MAX_IPFS_HASHES (50)
        for (uint i = 0; i < 51; i++) {
            ipfsHashes[i] = string(abi.encodePacked("QmHash", i));
        }
        supplyChain.createProduct(100, 500, bytes32("loc"), ipfsHashes);
    }

    function testPauseUnpause() public {
        supplyChain.pause();
        
        vm.prank(farmer);
        vm.expectRevert("Pausable: paused");
        supplyChain.createProduct(100, 500, bytes32("loc"), new string[](0));
        
        supplyChain.unpause();
        
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(100, 500, bytes32("loc"), new string[](0));
        assertGt(id, 0);
    }

    function testRoleManagement() public {
        address newFarmer = address(0x4);
        
        // Grant farmer role
        supplyChain.grantFarmerRole(newFarmer);
        assertTrue(supplyChain.hasRole(supplyChain.FARMER_ROLE(), newFarmer));
        
        // New farmer can create products
        vm.prank(newFarmer);
        uint256 id = supplyChain.createProduct(50, 300, bytes32("newLoc"), new string[](0));
        assertGt(id, 0);
    }

    function testRemoveProduct() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(100, 500, bytes32("loc"), new string[](0));
        
        // Admin can remove product
        supplyChain.removeProduct(id);
        
        // Product should no longer exist
        vm.expectRevert();
        supplyChain.getProduct(id);
    }

    function testGetProductIPFSHashes() public {
        vm.prank(farmer);
        string[] memory ipfsHashes = new string[](3);
        ipfsHashes[0] = "QmHash1";
        ipfsHashes[1] = "QmHash2";
        ipfsHashes[2] = "QmHash3";
        
        uint256 id = supplyChain.createProduct(100, 500, bytes32("loc"), ipfsHashes);
        
        string[] memory retrievedHashes = supplyChain.getProductIPFSHashes(id);
        assertEq(retrievedHashes.length, 3);
        assertEq(retrievedHashes[0], "QmHash1");
        assertEq(retrievedHashes[1], "QmHash2");
        assertEq(retrievedHashes[2], "QmHash3");
    }

    function testGetQualityIPFSHashes() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(100, 500, bytes32("loc"), new string[](0));
        
        vm.prank(farmer);
        supplyChain.addQualityData(id, 20, 60, 85, bytes32("cert1"), "QmQualityHash1");
        
        vm.prank(farmer);
        supplyChain.addQualityData(id, 22, 65, 90, bytes32("cert2"), "QmQualityHash2");
        
        string[] memory qualityHashes = supplyChain.getQualityIPFSHashes(id);
        assertEq(qualityHashes.length, 2);
        assertEq(qualityHashes[0], "QmQualityHash1");
        assertEq(qualityHashes[1], "QmQualityHash2");
    }

    function testDistributorCanUpdateProcessingStage() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(100, 500, bytes32("loc"), new string[](0));
        
        // First move to harvested (farmer can do this)
        vm.prank(farmer);
        supplyChain.updateProductStage(id, AgricultureSupplyChain.ProductStage.Harvested);
        
        // Now distributor can move to processed
        vm.prank(distributor);
        supplyChain.updateProductStage(id, AgricultureSupplyChain.ProductStage.Processed);
        
        (, , , , , AgricultureSupplyChain.ProductStage stage) = supplyChain.getProduct(id);
        assertEq(uint8(stage), uint8(AgricultureSupplyChain.ProductStage.Processed));
    }

    function testRetailerCanUpdateRetailStage() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(100, 500, bytes32("loc"), new string[](0));
        
        // Move through stages to distributed (distributor can do this)
        vm.prank(farmer);
        supplyChain.updateProductStage(id, AgricultureSupplyChain.ProductStage.Harvested);
        
        vm.prank(distributor);
        supplyChain.updateProductStage(id, AgricultureSupplyChain.ProductStage.Distributed);
        
        // Now retailer can move to retail
        vm.prank(retailer);
        supplyChain.updateProductStage(id, AgricultureSupplyChain.ProductStage.Retail);
        
        (, , , , , AgricultureSupplyChain.ProductStage stage) = supplyChain.getProduct(id);
        assertEq(uint8(stage), uint8(AgricultureSupplyChain.ProductStage.Retail));
    }
}