// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from"@openzeppelin/contracts/utils/Pausable.sol";

contract AgricultureSupplyChain is AccessControl, ReentrancyGuard, Pausable {
    error ProductNotFound();
    error UnauthorizedAccess();

    bytes32 public constant FARMER_ROLE = keccak256("FARMER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");

    enum ProductStage {
        Planted,
        Growing,
        Harvested,
        Processed,
        Packaged,
        InTransit,
        Distributed,
        Retail,
        Sold
    }

    struct ProductInfo {
        uint128 productId;
        uint64 timestamp;
        uint32 quantity;
        uint32 price;
        address owner;
        ProductStage stage;
        bytes32 locationHash;
        string[] ipfsHashes;  // Store IPFS hashes of certificates, documents, images
    }

    struct QualityData {
        uint64 timestamp;
        uint32 temperature;
        uint32 humidity;
        uint16 qualityScore;
        bytes32 certificationHash;
        string ipfsHash; // IPFS hash for detailed quality reports or certificates
    }

    mapping(uint256 => ProductInfo) public products;
    mapping(uint256 => QualityData[]) public productQuality;
    mapping(address => uint256[]) public ownerProducts;
    uint256 private _productCounter;

    event ProductCreated(uint256 indexed productId, address indexed farmer, uint256 quantity);
    event ProductUpdated(uint256 indexed productId, ProductStage newStage, address updatedBy);
    event QualityDataAdded(uint256 indexed productId, uint256 qualityScore);
    event OwnershipTransferred(uint256 indexed productId, address indexed from, address indexed to);
    event ProductIPFSHashAdded(uint256 indexed productId, string ipfsHash);
    event QualityDataIPFSHashAdded(uint256 indexed productId, string ipfsHash);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGULATOR_ROLE, msg.sender);
    }

    function createProduct(
        uint32 quantity,
        uint32 price,
        bytes32 locationHash,
        string[] memory ipfsHashes  // New param to add IPFS hashes on create
    ) external onlyRole(FARMER_ROLE) whenNotPaused nonReentrant returns (uint256) {
        uint256 productId = ++_productCounter;
        ProductInfo storage product = products[productId];
        product.productId = uint128(productId);
        product.timestamp = uint64(block.timestamp);
        product.quantity = quantity;
        product.price = price;
        product.owner = msg.sender;
        product.stage = ProductStage.Planted;
        product.locationHash = locationHash;

        // Add IPFS hashes
        for (uint i = 0; i < ipfsHashes.length; i++) {
            product.ipfsHashes.push(ipfsHashes[i]);
            emit ProductIPFSHashAdded(productId, ipfsHashes[i]);
        }

        ownerProducts[msg.sender].push(productId);
        emit ProductCreated(productId, msg.sender, quantity);
        return productId;
    }

    // Add IPFS hash to product later
    function addProductIPFSHash(uint256 productId, string memory ipfsHash) external onlyRole(FARMER_ROLE) {
        if (products[productId].productId == 0) revert ProductNotFound();
        products[productId].ipfsHashes.push(ipfsHash);
        emit ProductIPFSHashAdded(productId, ipfsHash);
    }

    function updateProductStage(
        uint256 productId,
        ProductStage newStage
    ) external whenNotPaused nonReentrant {
        ProductInfo storage product = products[productId];
        if (product.productId == 0) revert ProductNotFound();
        require(_canUpdateStage(msg.sender, newStage), "Unauthorized");
        product.stage = newStage;
        product.timestamp = uint64(block.timestamp);
        emit ProductUpdated(productId, newStage, msg.sender);
    }

    function addQualityData(
        uint256 productId,
        uint32 temperature,
        uint32 humidity,
        uint16 qualityScore,
        bytes32 certificationHash,
        string memory ipfsHash  // IPFS link for detailed quality data/certificate
    ) external whenNotPaused nonReentrant {
        if (products[productId].productId == 0) revert ProductNotFound();
        productQuality[productId].push(QualityData({
            timestamp: uint64(block.timestamp),
            temperature: temperature,
            humidity: humidity,
            qualityScore: qualityScore,
            certificationHash: certificationHash,
            ipfsHash: ipfsHash
        }));
        emit QualityDataAdded(productId, qualityScore);
        emit QualityDataIPFSHashAdded(productId, ipfsHash);
    }

    function transferOwnership(
        uint256 productId,
        address newOwner,
        uint32 newPrice
    ) external whenNotPaused nonReentrant {
        ProductInfo storage product = products[productId];
        if (product.productId == 0) revert ProductNotFound();
        require(product.owner == msg.sender, "Unauthorized");
        address previousOwner = product.owner;
        product.owner = newOwner;
        product.price = newPrice;
        product.timestamp = uint64(block.timestamp);
        ownerProducts[newOwner].push(productId);
        emit OwnershipTransferred(productId, previousOwner, newOwner);
    }

    // Internal role checks unchanged
    function _canUpdateStage(address sender, ProductStage stage) internal view returns (bool) {
        if (hasRole(REGULATOR_ROLE, sender)) return true;
        if (stage == ProductStage.Planted || stage == ProductStage.Growing || stage == ProductStage.Harvested)
            return hasRole(FARMER_ROLE, sender);
        else if (stage == ProductStage.Processed || stage == ProductStage.Packaged)
            return hasRole(FARMER_ROLE, sender) || hasRole(DISTRIBUTOR_ROLE, sender);
        else if (stage == ProductStage.InTransit || stage == ProductStage.Distributed)
            return hasRole(DISTRIBUTOR_ROLE, sender);
        else if (stage == ProductStage.Retail || stage == ProductStage.Sold)
            return hasRole(RETAILER_ROLE, sender);
        return false;
    }

    // Admin functions (unchanged)
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }
    function grantFarmerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) { grantRole(FARMER_ROLE, account); }
    function grantDistributorRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) { grantRole(DISTRIBUTOR_ROLE, account); }
    function grantRetailerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) { grantRole(RETAILER_ROLE, account); }
}
