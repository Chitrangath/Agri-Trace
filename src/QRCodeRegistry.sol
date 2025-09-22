// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract QRCodeRegistry is AccessControl {
    error QRCodeAlreadyRegistered();
    error QRCodeNotFound();
    error InvalidQRCodeHash();
    error InvalidProductId();
    error UnauthorizedDeactivation();

    // Gas optimized struct packing
    struct QRData {
        address creator;        // 20 bytes - slot 0
        uint64 timestamp;       // 8 bytes - fits in slot 0
        uint32 productId;       // 4 bytes - fits in slot 0 (32 bytes total)
        bool active;            // 1 bit - uses next slot due to alignment
    }

    mapping(bytes32 => QRData) public qrCodes;
    mapping(uint256 => bytes32) public productQRCodes;
    mapping(bytes32 => string) public qrMetadataHashes; // Separate mapping for IPFS hashes
    
    // Track QR codes per user for better management
    mapping(address => bytes32[]) public userQRCodes;
    
    uint256 public totalQRCodes;

    event QRCodeRegistered(bytes32 indexed qrHash, uint256 indexed productId, address indexed creator);
    event QRCodeDeactivated(bytes32 indexed qrHash);
    event QRCodeReactivated(bytes32 indexed qrHash);

    modifier validQRHash(bytes32 qrHash) {
        if (qrHash == bytes32(0)) revert InvalidQRCodeHash();
        _;
    }

    modifier qrExists(bytes32 qrHash) {
        if (qrCodes[qrHash].creator == address(0)) revert QRCodeNotFound();
        _;
    }

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
        uint32 productId, // Changed to uint32 for gas optimization
        string calldata ipfsMetadataHash // Use calldata for gas optimization
    ) external validQRHash(qrHash) returns (bool) {
        if (qrCodes[qrHash].creator != address(0)) revert QRCodeAlreadyRegistered();
        if (productId == 0) revert InvalidProductId();
        
        // Check if product already has a QR code
        if (productQRCodes[productId] != bytes32(0)) revert QRCodeAlreadyRegistered();
        
        qrCodes[qrHash] = QRData({
            productId: productId,
            creator: msg.sender,
            timestamp: uint64(block.timestamp),
            active: true
        });
        
        productQRCodes[productId] = qrHash;
        userQRCodes[msg.sender].push(qrHash);
        
        // Store IPFS metadata hash if provided
        if (bytes(ipfsMetadataHash).length > 0) {
            qrMetadataHashes[qrHash] = ipfsMetadataHash;
        }
        
        totalQRCodes++;
        
        emit QRCodeRegistered(qrHash, productId, msg.sender);
        return true;
    }

    /**
     * @dev Get product ID from QR code
     * @param qrHash The hash of the QR code to query
     */
    function getProductFromQR(bytes32 qrHash) 
        external 
        view 
        validQRHash(qrHash)
        qrExists(qrHash)
        returns (uint256) 
    {
        QRData storage qrData = qrCodes[qrHash];
        if (!qrData.active) revert QRCodeNotFound();
        return qrData.productId;
    }

    /**
     * @dev Get IPFS metadata hash for a QR code
     * @param qrHash The hash of the QR code to query
     */
    function getIPFSMetadata(bytes32 qrHash) 
        external 
        view 
        validQRHash(qrHash)
        qrExists(qrHash)
        returns (string memory) 
    {
        QRData storage qrData = qrCodes[qrHash];
        if (!qrData.active) revert QRCodeNotFound();
        return qrMetadataHashes[qrHash];
    }

    /**
     * @dev Update IPFS metadata hash for a QR code
     * @param qrHash The hash of the QR code to update
     * @param ipfsMetadataHash New IPFS hash
     */
    function updateIPFSMetadata(bytes32 qrHash, string calldata ipfsMetadataHash) 
        external 
        validQRHash(qrHash)
        qrExists(qrHash)
    {
        QRData storage qrData = qrCodes[qrHash];
        if (qrData.creator != msg.sender && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedDeactivation();
        }
        
        qrMetadataHashes[qrHash] = ipfsMetadataHash;
    }

    /**
     * @dev Deactivate a QR code
     * @param qrHash The hash of the QR code to deactivate
     */
    function deactivateQRCode(bytes32 qrHash) 
        external 
        validQRHash(qrHash)
        qrExists(qrHash)
    {
        QRData storage qrData = qrCodes[qrHash];
        if (qrData.creator != msg.sender && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedDeactivation();
        }
        
        if (!qrData.active) revert QRCodeNotFound(); // Already deactivated
        
        qrData.active = false;
        emit QRCodeDeactivated(qrHash);
    }

    /**
     * @dev Reactivate a QR code (admin or creator only)
     * @param qrHash The hash of the QR code to reactivate
     */
    function reactivateQRCode(bytes32 qrHash) 
        external 
        validQRHash(qrHash)
        qrExists(qrHash)
    {
        QRData storage qrData = qrCodes[qrHash];
        if (qrData.creator != msg.sender && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedDeactivation();
        }
        
        if (qrData.active) revert QRCodeAlreadyRegistered(); // Already active
        
        qrData.active = true;
        emit QRCodeReactivated(qrHash);
    }

    /**
     * @dev Get QR code data
     * @param qrHash The hash of the QR code to query
     */
    function getQRData(bytes32 qrHash) 
        external 
        view 
        validQRHash(qrHash)
        qrExists(qrHash)
        returns (
            uint256 productId,
            address creator,
            uint64 timestamp,
            bool active,
            string memory ipfsHash
        ) 
    {
        QRData storage qrData = qrCodes[qrHash];
        return (
            qrData.productId,
            qrData.creator,
            qrData.timestamp,
            qrData.active,
            qrMetadataHashes[qrHash]
        );
    }

    /**
     * @dev Get all QR codes created by a user
     * @param user The address to query
     */
    function getUserQRCodes(address user) external view returns (bytes32[] memory) {
        return userQRCodes[user];
    }

    /**
     * @dev Check if QR code is active
     * @param qrHash The hash of the QR code to check
     */
    function isQRCodeActive(bytes32 qrHash) 
        external 
        view 
        validQRHash(qrHash)
        returns (bool) 
    {
        QRData storage qrData = qrCodes[qrHash];
        return qrData.creator != address(0) && qrData.active;
    }

    /**
     * @dev Get QR code hash by product ID
     * @param productId The product ID to query
     */
    function getQRHashByProductId(uint256 productId) external view returns (bytes32) {
        return productQRCodes[productId];
    }

    // Admin function to bulk deactivate QR codes
    function bulkDeactivateQRCodes(bytes32[] calldata qrHashes) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        for (uint256 i = 0; i < qrHashes.length; ++i) {
            bytes32 qrHash = qrHashes[i];
            if (qrCodes[qrHash].creator != address(0) && qrCodes[qrHash].active) {
                qrCodes[qrHash].active = false;
                emit QRCodeDeactivated(qrHash);
            }
        }
    }
}