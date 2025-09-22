// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract AgricultureSupplyChain is AccessControl, ReentrancyGuard, Pausable {
    error ProductNotFound();
    error UnauthorizedAccess();
    error InvalidQuantity();
    error InvalidPrice();
    error ExceedsMaxIPFSHashes();

    bytes32 public constant FARMER_ROLE = keccak256("FARMER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");

    // Gas optimization: Pack enums to fit in smaller storage slots
    enum ProductStage {
        Planted,    // 0
        Growing,    // 1
        Harvested,  // 2
        Processed,  // 3
        Packaged,   // 4
        InTransit,  // 5
        Distributed,// 6
        Retail,     // 7
        Sold        // 8
    }

    // Gas optimization: Pack struct to minimize storage slots
    struct ProductInfo {
        address owner;          // 20 bytes - slot 0
        uint96 price;          // 12 bytes - fits in slot 0 (32 bytes total)
        uint128 productId;     // 16 bytes - slot 1
        uint64 timestamp;      // 8 bytes - fits in slot 1
        uint32 quantity;       // 4 bytes - fits in slot 1
        uint8 stage;           // 1 byte - fits in slot 1 (29 bytes used)
        bytes32 locationHash;  // 32 bytes - slot 2
    }

    // Gas optimization: Pack quality data struct
    struct QualityData {
        uint64 timestamp;      // 8 bytes - slot 0
        uint32 temperature;    // 4 bytes - fits in slot 0
        uint32 humidity;       // 4 bytes - fits in slot 0
        uint16 qualityScore;   // 2 bytes - fits in slot 0 (18 bytes used)
        bytes32 certificationHash; // 32 bytes - slot 1
    }

    mapping(uint256 => ProductInfo) public products;
    mapping(uint256 => QualityData[]) public productQuality;
    mapping(uint256 => string[]) public productIPFSHashes; // Separate mapping for gas optimization
    mapping(uint256 => string[]) public qualityIPFSHashes; // Separate mapping for quality IPFS hashes
    mapping(address => uint256[]) public ownerProducts;
    
    uint256 private _productCounter;
    uint256 public constant MAX_IPFS_HASHES = 50; // Prevent unbounded arrays

    event ProductCreated(uint256 indexed productId, address indexed farmer, uint256 quantity);
    event ProductUpdated(uint256 indexed productId, ProductStage newStage, address updatedBy);
    event QualityDataAdded(uint256 indexed productId, uint256 qualityScore);
    event OwnershipTransferred(uint256 indexed productId, address indexed from, address indexed to);
    event ProductIPFSHashAdded(uint256 indexed productId, string ipfsHash);
    event QualityDataIPFSHashAdded(uint256 indexed productId, string ipfsHash);

    modifier validProductId(uint256 productId) {
        if (products[productId].productId == 0) revert ProductNotFound();
        _;
    }

    modifier validQuantityAndPrice(uint32 quantity, uint96 price) {
        if (quantity == 0) revert InvalidQuantity();
        if (price == 0) revert InvalidPrice();
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGULATOR_ROLE, msg.sender);
    }

    function createProduct(
        uint32 quantity,
        uint96 price, // Changed to uint96 for better packing
        bytes32 locationHash,
        string[] calldata ipfsHashes // Use calldata for gas optimization
    ) external 
        onlyRole(FARMER_ROLE) 
        whenNotPaused 
        nonReentrant 
        validQuantityAndPrice(quantity, price)
        returns (uint256) 
    {
        if (ipfsHashes.length > MAX_IPFS_HASHES) revert ExceedsMaxIPFSHashes();
        
        uint256 productId = ++_productCounter;
        
        // Gas optimization: Use memory struct then assign to storage
        ProductInfo memory newProduct = ProductInfo({
            productId: uint128(productId),
            timestamp: uint64(block.timestamp),
            quantity: quantity,
            price: price,
            owner: msg.sender,
            stage: uint8(ProductStage.Planted),
            locationHash: locationHash
        });
        
        products[productId] = newProduct;

        // Add IPFS hashes if provided
        if (ipfsHashes.length > 0) {
            string[] storage productHashes = productIPFSHashes[productId];
            for (uint256 i = 0; i < ipfsHashes.length; ++i) {
                productHashes.push(ipfsHashes[i]);
                emit ProductIPFSHashAdded(productId, ipfsHashes[i]);
            }
        }

        ownerProducts[msg.sender].push(productId);
        emit ProductCreated(productId, msg.sender, quantity);
        return productId;
    }

    function addProductIPFSHash(uint256 productId, string calldata ipfsHash) 
        external 
        onlyRole(FARMER_ROLE) 
        validProductId(productId)
    {
        if (productIPFSHashes[productId].length >= MAX_IPFS_HASHES) revert ExceedsMaxIPFSHashes();
        
        productIPFSHashes[productId].push(ipfsHash);
        emit ProductIPFSHashAdded(productId, ipfsHash);
    }

    function updateProductStage(uint256 productId, ProductStage newStage) 
        external 
        whenNotPaused 
        nonReentrant 
        validProductId(productId)
    {
        if (!_canUpdateStage(msg.sender, newStage)) revert UnauthorizedAccess();
        
        ProductInfo storage product = products[productId];
        product.stage = uint8(newStage);
        product.timestamp = uint64(block.timestamp);
        
        emit ProductUpdated(productId, newStage, msg.sender);
    }

    function addQualityData(
        uint256 productId,
        uint32 temperature,
        uint32 humidity,
        uint16 qualityScore,
        bytes32 certificationHash,
        string calldata ipfsHash
    ) external 
        whenNotPaused 
        nonReentrant 
        validProductId(productId)
    {
        if (qualityIPFSHashes[productId].length >= MAX_IPFS_HASHES) revert ExceedsMaxIPFSHashes();
        
        productQuality[productId].push(QualityData({
            timestamp: uint64(block.timestamp),
            temperature: temperature,
            humidity: humidity,
            qualityScore: qualityScore,
            certificationHash: certificationHash
        }));
        
        qualityIPFSHashes[productId].push(ipfsHash);
        
        emit QualityDataAdded(productId, qualityScore);
        emit QualityDataIPFSHashAdded(productId, ipfsHash);
    }

    function transferOwnership(
        uint256 productId,
        address newOwner,
        uint96 newPrice
    ) external 
        whenNotPaused 
        nonReentrant 
        validProductId(productId)
    {
        ProductInfo storage product = products[productId];
        if (product.owner != msg.sender) revert UnauthorizedAccess();
        if (newOwner == address(0)) revert UnauthorizedAccess();
        if (newPrice == 0) revert InvalidPrice();
        
        address previousOwner = product.owner;
        product.owner = newOwner;
        product.price = newPrice;
        product.timestamp = uint64(block.timestamp);
        
        ownerProducts[newOwner].push(productId);
        
        emit OwnershipTransferred(productId, previousOwner, newOwner);
    }

    // View functions for tests and frontend
    function getProduct(uint256 productId) 
    external 
    view 
    validProductId(productId)
    returns (
        uint128 id,
        uint64 timestamp,
        uint32 quantity,
        uint96 price,
        address owner,
        ProductStage stage
    ) 
{
    ProductInfo memory product = products[productId];
    return (
        product.productId,
        product.timestamp,
        product.quantity,
        product.price,
        product.owner,
        ProductStage(product.stage)
    );
}

    function getQualityHistory(uint256 productId) 
        external 
        view 
        validProductId(productId)
        returns (QualityData[] memory qualities, string[] memory ipfsHashes) 
    {
        return (productQuality[productId], qualityIPFSHashes[productId]);
    }

    function getProductIPFSHashes(uint256 productId) 
        external 
        view 
        validProductId(productId)
        returns (string[] memory) 
    {
        return productIPFSHashes[productId];
    }

    function getQualityIPFSHashes(uint256 productId) 
        external 
        view 
        validProductId(productId)
        returns (string[] memory) 
    {
        return qualityIPFSHashes[productId];
    }

    function _canUpdateStage(address sender, ProductStage stage) internal view returns (bool) {
        if (hasRole(REGULATOR_ROLE, sender)) return true;
        
        if (stage <= ProductStage.Harvested) {
            return hasRole(FARMER_ROLE, sender);
        } else if (stage <= ProductStage.Packaged) {
            return hasRole(FARMER_ROLE, sender) || hasRole(DISTRIBUTOR_ROLE, sender);
        } else if (stage <= ProductStage.Distributed) {
            return hasRole(DISTRIBUTOR_ROLE, sender);
        } else {
            return hasRole(RETAILER_ROLE, sender);
        }
    }

    // Admin functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) { 
        _pause(); 
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) { 
        _unpause(); 
    }
    
    function grantFarmerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) { 
        grantRole(FARMER_ROLE, account); 
    }
    
    function grantDistributorRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) { 
        grantRole(DISTRIBUTOR_ROLE, account); 
    }
    
    function grantRetailerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) { 
        grantRole(RETAILER_ROLE, account); 
    }

    // Emergency function to remove products (for data protection compliance)
    function removeProduct(uint256 productId) 
        external 
        onlyRole(REGULATOR_ROLE) 
        validProductId(productId)
    {
        delete products[productId];
        delete productQuality[productId];
        delete productIPFSHashes[productId];
        delete qualityIPFSHashes[productId];
    }
}