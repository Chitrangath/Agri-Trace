// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {QRCodeRegistry} from "../src/QRCodeRegistry.sol";

contract QRCodeRegistryTest is Test {
    QRCodeRegistry qr;
    address user = address(0x1);
    address user2 = address(0x2);
    address admin;

    function setUp() public {
        admin = address(this);
        qr = new QRCodeRegistry();
    }

    function testRegisterQRCodeWithIPFS() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("product1"));
        string memory ipfsMetadata = "QmMetadataHash";
        
        bool success = qr.registerQRCode(qrhash, 1, ipfsMetadata);
        assertTrue(success);
        
        uint256 pid = qr.getProductFromQR(qrhash);
        assertEq(pid, 1);
        
        string memory metaOut = qr.getIPFSMetadata(qrhash);
        assertEq(metaOut, ipfsMetadata);
        
        assertTrue(qr.isQRCodeActive(qrhash));
        assertEq(qr.totalQRCodes(), 1);
    }

    function testRegisterQRCodeWithoutIPFS() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("product2"));
        
        bool success = qr.registerQRCode(qrhash, 2, "");
        assertTrue(success);
        
        uint256 pid = qr.getProductFromQR(qrhash);
        assertEq(pid, 2);
        
        string memory metaOut = qr.getIPFSMetadata(qrhash);
        assertEq(bytes(metaOut).length, 0); // Empty string
    }

    function testGetQRData() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("product3"));
        string memory ipfsMetadata = "QmDetailedMetadata";
        
        qr.registerQRCode(qrhash, 3, ipfsMetadata);
        
        (uint256 productId, address creator, uint64 timestamp, bool active, string memory ipfsHash) = qr.getQRData(qrhash);
        
        assertEq(productId, 3);
        assertEq(creator, user);
        assertGt(timestamp, 0);
        assertTrue(active);
        assertEq(ipfsHash, ipfsMetadata);
    }

    function testUpdateIPFSMetadata() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("product4"));
        
        qr.registerQRCode(qrhash, 4, "OldHash");
        
        vm.prank(user);
        qr.updateIPFSMetadata(qrhash, "NewHash");
        
        string memory updatedHash = qr.getIPFSMetadata(qrhash);
        assertEq(updatedHash, "NewHash");
    }

    function testDeactivateAndReactivateQRCode() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("product5"));
        
        qr.registerQRCode(qrhash, 5, "");
        assertTrue(qr.isQRCodeActive(qrhash));
        
        // Deactivate
        vm.prank(user);
        qr.deactivateQRCode(qrhash);
        assertFalse(qr.isQRCodeActive(qrhash));
        
        // Should revert when trying to get product from deactivated QR
        vm.expectRevert();
        qr.getProductFromQR(qrhash);
        
        // Reactivate
        vm.prank(user);
        qr.reactivateQRCode(qrhash);
        assertTrue(qr.isQRCodeActive(qrhash));
        
        // Should work again
        uint256 pid = qr.getProductFromQR(qrhash);
        assertEq(pid, 5);
    }

    function testGetUserQRCodes() public {
        vm.startPrank(user);
        bytes32 qrhash1 = keccak256(abi.encodePacked("product6"));
        bytes32 qrhash2 = keccak256(abi.encodePacked("product7"));
        
        qr.registerQRCode(qrhash1, 6, "");
        qr.registerQRCode(qrhash2, 7, "");
        vm.stopPrank();
        
        bytes32[] memory userQRs = qr.getUserQRCodes(user);
        assertEq(userQRs.length, 2);
        assertEq(userQRs[0], qrhash1);
        assertEq(userQRs[1], qrhash2);
    }

    function testGetQRHashByProductId() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("product8"));
        
        qr.registerQRCode(qrhash, 8, "");
        
        bytes32 retrievedHash = qr.getQRHashByProductId(8);
        assertEq(retrievedHash, qrhash);
    }

    function testAdminDeactivate() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("product9"));
        qr.registerQRCode(qrhash, 9, "");
        
        // Admin can deactivate any QR code
        qr.deactivateQRCode(qrhash);
        assertFalse(qr.isQRCodeActive(qrhash));
    }

    function testAdminUpdateIPFSMetadata() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("product10"));
        qr.registerQRCode(qrhash, 10, "UserHash");
        
        // Admin can update any QR code's IPFS metadata
        qr.updateIPFSMetadata(qrhash, "AdminUpdatedHash");
        
        string memory updatedHash = qr.getIPFSMetadata(qrhash);
        assertEq(updatedHash, "AdminUpdatedHash");
    }

    function testBulkDeactivateQRCodes() public {
        vm.startPrank(user);
        bytes32 qrhash1 = keccak256(abi.encodePacked("product11"));
        bytes32 qrhash2 = keccak256(abi.encodePacked("product12"));
        bytes32 qrhash3 = keccak256(abi.encodePacked("product13"));
        
        qr.registerQRCode(qrhash1, 11, "");
        qr.registerQRCode(qrhash2, 12, "");
        qr.registerQRCode(qrhash3, 13, "");
        vm.stopPrank();
        
        bytes32[] memory qrHashes = new bytes32[](3);
        qrHashes[0] = qrhash1;
        qrHashes[1] = qrhash2;
        qrHashes[2] = qrhash3;
        
        // Admin bulk deactivate
        qr.bulkDeactivateQRCodes(qrHashes);
        
        assertFalse(qr.isQRCodeActive(qrhash1));
        assertFalse(qr.isQRCodeActive(qrhash2));
        assertFalse(qr.isQRCodeActive(qrhash3));
    }

    function testFailDuplicateQRRegistration() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("duplicate"));
        qr.registerQRCode(qrhash, 14, "");
        
        vm.prank(user2);
        qr.registerQRCode(qrhash, 15, ""); // Should fail
    }

    function testFailDuplicateProductId() public {
        vm.prank(user);
        bytes32 qrhash1 = keccak256(abi.encodePacked("qr1"));
        qr.registerQRCode(qrhash1, 16, "");
        
        vm.prank(user2);
        bytes32 qrhash2 = keccak256(abi.encodePacked("qr2"));
        qr.registerQRCode(qrhash2, 16, ""); // Same product ID should fail
    }

    function testFailRegisterZeroQRHash() public {
        vm.prank(user);
        qr.registerQRCode(bytes32(0), 17, ""); // Should fail
    }

    function testFailRegisterZeroProductId() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("valid"));
        qr.registerQRCode(qrhash, 0, ""); // Should fail
    }

    function testFailUnauthorizedDeactivation() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("protected"));
        qr.registerQRCode(qrhash, 18, "");
        
        vm.prank(user2); // Different user
        qr.deactivateQRCode(qrhash); // Should fail
    }

    function testFailUnauthorizedIPFSUpdate() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("protected2"));
        qr.registerQRCode(qrhash, 19, "OriginalHash");
        
        vm.prank(user2); // Different user
        qr.updateIPFSMetadata(qrhash, "HackedHash"); // Should fail
    }

    function testFailGetProductFromNonexistentQR() public {
        bytes32 qrhash = keccak256(abi.encodePacked("nonexistent"));
        qr.getProductFromQR(qrhash); // Should fail
    }

    function testFailGetDataFromDeactivatedQR() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("deactivated"));
        qr.registerQRCode(qrhash, 20, "");
        
        vm.prank(user);
        qr.deactivateQRCode(qrhash);
        
        qr.getIPFSMetadata(qrhash); // Should fail
    }

    function testFailReactivateActiveQR() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("active"));
        qr.registerQRCode(qrhash, 21, "");
        
        vm.prank(user);
        qr.reactivateQRCode(qrhash); // Should fail - already active
    }

    function testFailDeactivateAlreadyDeactivatedQR() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("deactivated2"));
        qr.registerQRCode(qrhash, 22, "");
        
        vm.prank(user);
        qr.deactivateQRCode(qrhash);
        
        vm.prank(user);
        qr.deactivateQRCode(qrhash); // Should fail - already deactivated
    }
}