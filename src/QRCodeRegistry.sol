// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract QRCodeRegistry is AccessControl {
    error QRCodeAlreadyRegistered();
    error QRCodeNotFound();

    struct QRData {
        uint256 productId;
        address creator;
        uint64 timestamp;
        bool active;
        string ipfsMetadataHash;  // Optional IPFS hash for QR-related metadata
    }

    mapping(bytes32 => QRData) public qrCodes;
    mapping(uint256 => bytes32) public productQRCodes;

    event QRCodeRegistered(bytes32 indexed qrHash, uint256 indexed productId, address indexed creator);
    event QRCodeDeactivated(bytes32 indexed qrHash);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Register a QR code for a product, with optional IPFS metadata hash
     * @param qrHash The hash of the QR code unique identifier
     * @param productId The product ID this QR code references
     * @param ipfsMetadataHash IPFS hash linking to additional QR metadata (optional)
     */
    function registerQRCode(
        bytes32 qrHash,
        uint256 productId,
        string memory ipfsMetadataHash
    ) external returns (bool) {
        if (qrCodes[qrHash].creator != address(0)) revert QRCodeAlreadyRegistered();
        qrCodes[qrHash] = QRData({
            productId: productId,
            creator: msg.sender,
            timestamp: uint64(block.timestamp),
            active: true,
            ipfsMetadataHash: ipfsMetadataHash
        });
        productQRCodes[productId] = qrHash;
        emit QRCodeRegistered(qrHash, productId, msg.sender);
        return true;
    }

    /**
     * @dev Get product ID from QR code
     * @param qrHash The hash of the QR code to query
     */
    function getProductFromQR(bytes32 qrHash) external view returns (uint256) {
        QRData memory qrData = qrCodes[qrHash];
        if (qrData.creator == address(0) || !qrData.active) revert QRCodeNotFound();
        return qrData.productId;
    }

    /**
     * @dev Get IPFS metadata hash for a QR code
     * @param qrHash The hash of the QR code to query
     */
    function getIPFSMetadata(bytes32 qrHash) external view returns (string memory) {
        QRData memory qrData = qrCodes[qrHash];
        if (qrData.creator == address(0) || !qrData.active) revert QRCodeNotFound();
        return qrData.ipfsMetadataHash;
    }

    /**
     * @dev Deactivate a QR code
     * @param qrHash The hash of the QR code to deactivate
     */
    function deactivateQRCode(bytes32 qrHash) external {
        QRData storage qrData = qrCodes[qrHash];
        if (qrData.creator != msg.sender && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert QRCodeNotFound();
        }
        qrData.active = false;
        emit QRCodeDeactivated(qrHash);
    }
}
