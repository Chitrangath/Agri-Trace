
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IAgricultureSupplyChain {
    function getProduct(uint256 productId) external view returns (
        uint128 id,
        uint64 timestamp,
        uint32 quantity,
        uint96 price,
        address owner,
        uint8 stage
    );
    function getQualityHistory(uint256 productId) external view returns (
        uint256[] memory qualities,
        string[] memory ipfsHashes
    );
    function getProductIPFSHashes(uint256 productId) external view returns (string[] memory);
}

interface IQRCodeRegistry {
    function getProductFromQR(bytes32 qrHash) external view returns (uint256);
    function isQRCodeActive(bytes32 qrHash) external view returns (bool);
}

interface IFairPricingContract {
    function getFarmerProfile(address farmer) external view returns (
        uint16 currentRating,
        uint32 totalTransactions,
        uint32 penaltyCount,
        bool isActive,
        uint64 lastActivity
    );
}

/**
 * @title ConsumerInterface  
 * @dev Consumer-friendly interface for easy product verification and transparency
 * @dev Simplifies complex blockchain interactions for end consumers
 */
contract ConsumerInterface is AccessControl, ReentrancyGuard {
    error ProductNotFound();
    error InvalidQRCode();
    error ContractNotConfigured();

    // Gas optimized consumer verification data
    struct ProductSummary {
        uint256 productId;              // 32 bytes - slot 0
        address farmer;                 // 20 bytes - slot 1
        uint96 currentPrice;            // 12 bytes - fits in slot 1 (32 bytes total)
        uint64 harvestTime;            // 8 bytes - slot 2
        uint32 quantity;               // 4 bytes - fits in slot 2
        uint16 qualityScore;           // 2 bytes - fits in slot 2
        uint8 currentStage;            // 1 byte - fits in slot 2
        bool isAuthentic;              // 1 byte - fits in slot 2 (16 bytes used)
    }

    // Farmer reputation summary for consumers
    struct FarmerReputation {
        address farmerAddress;         // 20 bytes - slot 0
        uint64 registrationDate;      // 8 bytes - fits in slot 0
        uint32 totalSales;            // 4 bytes - fits in slot 0 (32 bytes total)
        uint16 trustScore;            // 2 bytes - slot 1
        bool isVerified;              // 1 byte - fits in slot 1 (3 bytes used)
    }

    // Simple verification result for mobile apps
    struct VerificationResult {
        bool isValid;
        string status;
        uint256 productId;
        string farmerName;
        uint256 rating; // Out of 100 for simplicity
    }

    IAgricultureSupplyChain public supplyChainContract;
    IQRCodeRegistry public qrCodeRegistry; 
    IFairPricingContract public pricingContract;

    mapping(uint256 => string) public productNames; // Human-readable names
    mapping(address => string) public farmerNames; // Farmer display names
    mapping(uint256 => uint256) public productViews; // Track consumer interest
    mapping(uint256 => string[]) public productCertifications; // Certification labels

    // Consumer engagement tracking
    mapping(address => uint256[]) public consumerHistory; // Products viewed by consumer
    uint256 public totalVerifications;

    event ProductVerified(uint256 indexed productId, address indexed consumer, uint256 timestamp);
    event QRCodeScanned(bytes32 indexed qrHash, address indexed consumer, bool isValid);
    event ConsumerEducated(address indexed consumer, uint256 productId, string educationTopic);

    modifier contractsConfigured() {
        if (
            address(supplyChainContract) == address(0) || 
            address(qrCodeRegistry) == address(0) ||
            address(pricingContract) == address(0)
        ) revert ContractNotConfigured();
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Configure integrated contracts (admin only)
     */
    function configureContracts(
        address _supplyChainContract,
        address _qrCodeRegistry,
        address _pricingContract
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supplyChainContract = IAgricultureSupplyChain(_supplyChainContract);
        qrCodeRegistry = IQRCodeRegistry(_qrCodeRegistry);
        pricingContract = IFairPricingContract(_pricingContract);
    }

    /**
     * @dev Simple product verification by product ID (primary consumer function)
     * @param productId The product ID to verify
     * @return summary Complete product information in consumer-friendly format
     */
    function verifyProduct(uint256 productId) 
        external 
        nonReentrant 
        contractsConfigured
        returns (ProductSummary memory summary) 
    {
        // Get basic product data
        (
            uint128 id,
            uint64 timestamp,
            uint32 quantity,
            uint96 price,
            address owner,
            uint8 stage
        ) = supplyChainContract.getProduct(productId);

        if (id == 0) revert ProductNotFound();

        // Get quality data
        uint16 qualityScore = _getLatestQualityScore(productId);

        // Create consumer-friendly summary
        summary = ProductSummary({
            productId: productId,
            farmer: owner,
            currentPrice: price,
            harvestTime: timestamp,
            quantity: quantity,
            qualityScore: qualityScore,
            currentStage: stage,
            isAuthentic: true // Validated by being on blockchain
        });

        // Track consumer engagement
        consumerHistory[msg.sender].push(productId);
        productViews[productId]++;
        totalVerifications++;

        emit ProductVerified(productId, msg.sender, block.timestamp);
        return summary;
    }

    /**
     * @dev Verify product using QR code scan (mobile-friendly)
     * @param qrHash The QR code hash scanned by consumer
     * @return result Simple verification result
     */
    function verifyByQRCode(bytes32 qrHash) 
        external 
        nonReentrant 
        contractsConfigured
        returns (VerificationResult memory result) 
    {
        // Check if QR code is valid and active
        if (!qrCodeRegistry.isQRCodeActive(qrHash)) {
            emit QRCodeScanned(qrHash, msg.sender, false);
            return VerificationResult({
                isValid: false,
                status: "Invalid or inactive QR code",
                productId: 0,
                farmerName: "",
                rating: 0
            });
        }

        // Get product ID from QR code
        uint256 productId = qrCodeRegistry.getProductFromQR(qrHash);

        // Verify the product
        ProductSummary memory summary = this.verifyProduct(productId);

        // Get farmer reputation
        (uint16 farmerRating,,, bool farmerActive,) = pricingContract.getFarmerProfile(summary.farmer);

        result = VerificationResult({
            isValid: true,
            status: _getStageText(summary.currentStage),
            productId: productId,
            farmerName: farmerNames[summary.farmer],
            rating: farmerActive ? (farmerRating * 100) / 5000 : 0 // Convert to 0-100 scale
        });

        emit QRCodeScanned(qrHash, msg.sender, true);
        return result;
    }

    /**
     * @dev Get detailed farmer information for transparency
     * @param farmer The farmer address to look up
     * @return reputation Farmer reputation data
     */
    function getFarmerReputation(address farmer) 
        external 
        view 
        contractsConfigured
        returns (FarmerReputation memory reputation) 
    {
        (
            uint16 currentRating,
            uint32 totalTransactions,
            ,
            bool isActive,
            uint64 lastActivity
        ) = pricingContract.getFarmerProfile(farmer);

        reputation = FarmerReputation({
            farmerAddress: farmer,
            registrationDate: lastActivity, // Simplified
            totalSales: totalTransactions,
            trustScore: currentRating,
            isVerified: isActive
        });
    }

    /**
     * @dev Get complete product journey for consumer education
     * @param productId Product to trace
     * @return stages Array of stage names
     * @return timestamps Array of stage timestamps  
     * @return qualityScores Array of quality scores at each stage
     */
    function getProductJourney(uint256 productId) 
        external 
        view 
        contractsConfigured
        returns (
            string[] memory stages,
            uint256[] memory timestamps,
            uint256[] memory qualityScores
        ) 
    {
        // Get current product data
        (,uint64 timestamp, uint32 quantity, uint96 price, address owner, uint8 stage) = 
            supplyChainContract.getProduct(productId);

        if (timestamp == 0) revert ProductNotFound();

        // Simplified journey - in production would track all stage changes
        stages = new string[](stage + 1);
        timestamps = new uint256[](stage + 1);
        qualityScores = new uint256[](stage + 1);

        // Fill in known stages
        for (uint8 i = 0; i <= stage; i++) {
            stages[i] = _getStageText(i);
            timestamps[i] = timestamp; // Simplified - would track each stage timestamp
            qualityScores[i] = _getLatestQualityScore(productId);
        }
    }

    /**
     * @dev Batch verify multiple products (for shopping apps)
     * @param productIds Array of product IDs to verify
     * @return summaries Array of product summaries
     */
    function batchVerifyProducts(uint256[] calldata productIds) 
        external 
        view 
        contractsConfigured
        returns (ProductSummary[] memory summaries) 
    {
        summaries = new ProductSummary[](productIds.length);

        for (uint256 i = 0; i < productIds.length; i++) {
            try supplyChainContract.getProduct(productIds[i]) returns (
                uint128 id,
                uint64 timestamp,
                uint32 quantity,
                uint96 price,
                address owner,
                uint8 stage
            ) {
                if (id != 0) {
                    summaries[i] = ProductSummary({
                        productId: productIds[i],
                        farmer: owner,
                        currentPrice: price,
                        harvestTime: timestamp,
                        quantity: quantity,
                        qualityScore: _getLatestQualityScore(productIds[i]),
                        currentStage: stage,
                        isAuthentic: true
                    });
                }
            } catch {
                // Invalid product - leave as default (productId = 0)
                continue;
            }
        }
    }

    /**
     * @dev Get consumer's verification history
     * @param consumer Consumer address
     * @return productIds Array of products verified by consumer
     */
    function getConsumerHistory(address consumer) 
        external 
        view 
        returns (uint256[] memory productIds) 
    {
        return consumerHistory[consumer];
    }

    /**
     * @dev Get product popularity metrics
     * @param productId Product to check
     * @return views Number of times product was verified
     * @return certifications Array of certification strings
     */
    function getProductMetrics(uint256 productId) 
        external 
        view 
        returns (uint256 views, string[] memory certifications) 
    {
        return (productViews[productId], productCertifications[productId]);
    }

    /**
     * @dev Internal function to get latest quality score
     */
    function _getLatestQualityScore(uint256 productId) internal view returns (uint16) {
        try supplyChainContract.getQualityHistory(productId) returns (
            uint256[] memory qualities,
            string[] memory
        ) {
            if (qualities.length > 0) {
                return uint16(qualities[qualities.length - 1]);
            }
        } catch {
            return 0;
        }
        return 0;
    }

    /**
     * @dev Convert stage number to readable text
     */
    function _getStageText(uint8 stage) internal pure returns (string memory) {
        if (stage == 0) return "Planted";
        if (stage == 1) return "Growing";
        if (stage == 2) return "Harvested";
        if (stage == 3) return "Processed";
        if (stage == 4) return "Packaged";
        if (stage == 5) return "In Transit";
        if (stage == 6) return "Distributed";
        if (stage == 7) return "At Retail";
        if (stage == 8) return "Sold";
        return "Unknown";
    }

    // Admin functions for data management
    function setProductName(uint256 productId, string calldata name) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        productNames[productId] = name;
    }

    function setFarmerName(address farmer, string calldata name) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        farmerNames[farmer] = name;
    }

    function addProductCertification(uint256 productId, string calldata certification) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        productCertifications[productId].push(certification);
    }
}
