// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/AgricultureSupplyChain.sol";

contract AgricultureSupplyChainTest is Test {
    AgricultureSupplyChain supplyChain;
    address farmer = address(0x1);
    address distributor = address(0x2);
    address retailer = address(0x3);

    function setUp() public {
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
        (,,, , address owner,, string[] memory hashes) = supplyChain.getProduct(id);
        assertEq(owner, farmer);
        assertEq(hashes.length, 2);
        assertEq(hashToBytes(hashes[0]), hashToBytes("QmTestHash1"));
        assertEq(hashToBytes(hashes[1]), hashToBytes("QmTestHash2"));
    }

    function testAddProductIPFSHash() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(50, 200, bytes32("loc"), new string[](0));
        vm.prank(farmer);
        supplyChain.addProductIPFSHash(id, "QmNewHash");
        (, , , , , , string[] memory hashes) = supplyChain.getProduct(id);
        assertEq(hashes[0], "QmNewHash");
    }

    function testAddQualityDataWithIPFS() public {
        vm.prank(farmer);
        uint256 id = supplyChain.createProduct(10, 150, bytes32("loc"), new string[](0));
        vm.prank(farmer);
        supplyChain.addQualityData(id, 25, 50, 90, bytes32(0), "QmQualityHash");
        AgricultureSupplyChain.QualityData[] memory qh = supplyChain.getQualityHistory(id);
        assertEq(qh.length, 1);
        assertEq(qh[0].ipfsHash, "QmQualityHash");
    }

    // Helper to compare strings as bytes (needed because assertEq doesn't support strings out-of-the-box)
    function hashToBytes(string memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(s));
    }
}
