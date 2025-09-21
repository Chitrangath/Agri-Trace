// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/QRCodeRegistry.sol";

contract QRCodeRegistryTest is Test {
    QRCodeRegistry qr;
    address user = address(0x1);

    function setUp() public {
        qr = new QRCodeRegistry();
    }

    function testRegisterQRCodeWithIPFS() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("product1"));
        string memory ipfsMetadata = "QmMetadataHash";
        qr.registerQRCode(qrhash, 1, ipfsMetadata);
        uint256 pid = qr.getProductFromQR(qrhash);
        assertEq(pid, 1);
        string memory metaOut = qr.getIPFSMetadata(qrhash);
        assertEq(metaOut, ipfsMetadata);
    }

    function testDeactivateQRCode() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("x2"));
        qr.registerQRCode(qrhash, 2, "");
        vm.prank(user);
        qr.deactivateQRCode(qrhash);
        vm.expectRevert();
        qr.getProductFromQR(qrhash);
    }

    function testFail_DuplicateQR() public {
        vm.prank(user);
        bytes32 qrhash = keccak256(abi.encodePacked("p3"));
        qr.registerQRCode(qrhash, 3, "");
        vm.prank(user);
        qr.registerQRCode(qrhash, 4, "");
    }
}
