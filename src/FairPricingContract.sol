
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

interface IAgricultureSupplyChain {
    function getProduct(uint256 productId) external view returns (
        uint128 id,
        uint64 timestamp,
        uint32 quantity,
        uint96 price,
        address owner,
        uint8 stage
    );
}

interface IPaymentContract {
    function createPayment(
        uint96 amount,
        address payee,
        uint64 dueDate,
        bytes32 conditionsHash
    ) external payable returns (uint256);
}

/**
 * @title FairPricingContract
 * @dev Enforces minimum support pricing and farmer protection mechanisms
 * @dev Gas optimized with packed structs and efficient storage usage
 */
contract FairPricingContract is AccessControl, ReentrancyGuard, Pausable {
    error InsufficientPrice();
    error FarmerNotRegistered();
    error InvalidPriceOracle();
    error PriceTooVolatile();
    error UnauthorizedPriceUpdate();
    error InvalidRating();
    error ExcessiveMarketDeviation();

    bytes32 public constant PRICE_ORACLE_ROLE = keccak256("PRICE_ORACLE_ROLE");
    bytes32 public constant FARMER_PROTECTION_ROLE = keccak256("FARMER_PROTECTION_ROLE");

    // Gas optimized struct packing
    struct FarmerProfile {
        address farmerAddress;      // 20 bytes - slot 0
        uint64 registrationTime;    // 8 bytes - fits in slot 0
        uint32 totalTransactions;   // 4 bytes - fits in slot 0 (32 bytes total)
        uint128 cumulativeRating;   // 16 bytes - slot 1
        uint64 lastActivityTime;    // 8 bytes - fits in slot 1
        uint32 penaltyCount;        // 4 bytes - fits in slot 1
        uint16 currentRating;       // 2 bytes - fits in slot 1
        bool isActive;              // 1 byte - fits in slot 1 (31 bytes used)
    }

    // Packed pricing data
    struct PriceData {
        uint128 minimumSupportPrice;    // 16 bytes - slot 0
        uint64 lastUpdated;            // 8 bytes - fits in slot 0
        uint32 volatilityIndex;        // 4 bytes - fits in slot 0
        uint16 marketConfidence;       // 2 bytes - fits in slot 0
        bool isActive;                 // 1 byte - fits in slot 0 (31 bytes used)
    }

    // Transaction validation data
    struct TransactionValidation {
        uint256 productId;         // 32 bytes - slot 0
        uint128 validatedPrice;    // 16 bytes - slot 1
        uint64 validationTime;     // 8 bytes - fits in slot 1
        uint32 marketVariance;     // 4 bytes - fits in slot 1
        bool isValidated;          // 1 byte - fits in slot 1 (29 bytes used)
    }

    mapping(address => FarmerProfile) public farmerProfiles;
    mapping(uint256 => PriceData) public productPricing; // productId => pricing data
    mapping(uint256 => TransactionValidation) public validatedTransactions;
    mapping(address => uint256[]) public farmerTransactions;

    // Oracle integration
    address public priceOracle;
    IAgricultureSupplyChain public immutable supplyChainContract;
    IPaymentContract public immutable paymentContract;

    uint128 public globalMinimumPrice = 1 ether; // Default 1 ETH minimum
    uint32 public maxVolatilityThreshold = 2000; // 20% in basis points
    uint16 public constant MAX_RATING = 5000; // 50.00 rating scale

    event FarmerRegistered(address indexed farmer, uint256 timestamp);
    event PriceValidated(uint256 indexed productId, uint256 validatedPrice, address indexed farmer);
    event FarmerRated(address indexed farmer, uint256 newRating, address indexed rater);
    event MinimumPriceUpdated(uint256 newPrice, address indexed updater);
    event PriceViolationDetected(uint256 indexed productId, uint256 attemptedPrice, uint256 minimumRequired);
    event FarmerProtectionTriggered(address indexed farmer, string reason);

    modifier onlyRegisteredFarmer() {
        if (!farmerProfiles[msg.sender].isActive) revert FarmerNotRegistered();
        _;
    }

    modifier validPrice(uint256 price) {
        if (price == 0) revert InsufficientPrice();
        _;
    }

    constructor(
        address _supplyChainContract,
        address _paymentContract,
        address _priceOracle
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRICE_ORACLE_ROLE, _priceOracle);
        _grantRole(FARMER_PROTECTION_ROLE, msg.sender);

        supplyChainContract = IAgricultureSupplyChain(_supplyChainContract);
        paymentContract = IPaymentContract(_paymentContract);
        priceOracle = _priceOracle;
    }

    /**
     * @dev Register a new farmer with protection mechanisms
     */
    function registerFarmer(address farmer) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        returns (bool) 
    {
        if (farmerProfiles[farmer].farmerAddress != address(0)) {
            // Reactivate if previously deactivated
            farmerProfiles[farmer].isActive = true;
            farmerProfiles[farmer].lastActivityTime = uint64(block.timestamp);
            return true;
        }

        farmerProfiles[farmer] = FarmerProfile({
            farmerAddress: farmer,
            registrationTime: uint64(block.timestamp),
            totalTransactions: 0,
            cumulativeRating: 0,
            lastActivityTime: uint64(block.timestamp),
            penaltyCount: 0,
            currentRating: MAX_RATING / 10, // Start with 5.0 rating
            isActive: true
        });

        emit FarmerRegistered(farmer, block.timestamp);
        return true;
    }

    /**
     * @dev Validate and enforce minimum pricing for a product
     */
    function validateProductPricing(
        uint256 productId,
        uint128 proposedPrice,
        address farmer
    ) external 
        whenNotPaused 
        nonReentrant 
        validPrice(proposedPrice)
        returns (bool) 
    {
        if (!farmerProfiles[farmer].isActive) revert FarmerNotRegistered();

        // Get current market price from oracle
        uint128 marketPrice = _getMarketPrice(productId);
        uint128 minimumRequired = _calculateMinimumPrice(productId, farmer, marketPrice);

        if (proposedPrice < minimumRequired) {
            emit PriceViolationDetected(productId, proposedPrice, minimumRequired);
            emit FarmerProtectionTriggered(farmer, "Price below minimum guarantee");
            revert InsufficientPrice();
        }

        // Check for excessive market deviation (potential manipulation)
        uint32 deviation = _calculateMarketDeviation(proposedPrice, marketPrice);
        if (deviation > maxVolatilityThreshold) {
            emit FarmerProtectionTriggered(farmer, "Excessive market deviation detected");
            revert PriceTooVolatile();
        }

        // Store validation data
        validatedTransactions[productId] = TransactionValidation({
            productId: productId,
            validatedPrice: proposedPrice,
            validationTime: uint64(block.timestamp),
            marketVariance: deviation,
            isValidated: true
        });

        // Update farmer activity
        farmerProfiles[farmer].lastActivityTime = uint64(block.timestamp);
        farmerProfiles[farmer].totalTransactions++;
        farmerTransactions[farmer].push(productId);

        emit PriceValidated(productId, proposedPrice, farmer);
        return true;
    }

    /**
     * @dev Rate a farmer's performance (affects pricing bonuses)
     */
    function rateFarmer(
        address farmer,
        uint16 rating,
        string calldata reason
    ) external 
        onlyRole(FARMER_PROTECTION_ROLE) 
    {
        if (!farmerProfiles[farmer].isActive) revert FarmerNotRegistered();
        if (rating > MAX_RATING) revert InvalidRating();

        FarmerProfile storage profile = farmerProfiles[farmer];

        // Update cumulative rating with weighted average
        uint128 totalRating = profile.cumulativeRating + rating;
        uint32 totalTransactions = profile.totalTransactions + 1;
        profile.currentRating = uint16(totalRating / totalTransactions);
        profile.cumulativeRating = totalRating;

        // Apply penalties for poor performance
        if (rating < MAX_RATING / 4) { // Below 12.5/50 (2.5/10)
            profile.penaltyCount++;
            if (profile.penaltyCount >= 5) {
                profile.isActive = false;
                emit FarmerProtectionTriggered(farmer, "Farmer suspended due to poor performance");
            }
        }

        emit FarmerRated(farmer, profile.currentRating, msg.sender);
    }

    /**
     * @dev Calculate minimum price with farmer rating bonus
     */
    function _calculateMinimumPrice(
        uint256 productId,
        address farmer,
        uint128 marketPrice
    ) internal view returns (uint128) {
        uint128 baseMinimum = productPricing[productId].minimumSupportPrice;
        if (baseMinimum == 0) {
            baseMinimum = globalMinimumPrice;
        }

        // Use higher of market price or MSP
        uint128 minimumPrice = marketPrice > baseMinimum ? marketPrice : baseMinimum;

        // Apply farmer rating bonus (up to 10% bonus for top ratings)
        FarmerProfile memory profile = farmerProfiles[farmer];
        if (profile.currentRating > MAX_RATING / 2) { // Above 25/50 (5/10)
            uint128 bonus = (minimumPrice * profile.currentRating) / (MAX_RATING * 10);
            minimumPrice += bonus;
        }

        return minimumPrice;
    }

    /**
     * @dev Get market price from oracle (simplified implementation)
     */
    function _getMarketPrice(uint256 productId) internal view returns (uint128) {
        // In production, this would call external price oracle
        // For now, return stored price or global minimum
        uint128 storedPrice = productPricing[productId].minimumSupportPrice;
        return storedPrice > 0 ? storedPrice : globalMinimumPrice;
    }

    /**
     * @dev Calculate market deviation percentage
     */
    function _calculateMarketDeviation(uint128 proposedPrice, uint128 marketPrice) 
        internal 
        pure 
        returns (uint32) 
    {
        if (marketPrice == 0) return 0;

        uint128 difference = proposedPrice > marketPrice ? 
            proposedPrice - marketPrice : marketPrice - proposedPrice;

        return uint32((difference * 10000) / marketPrice); // Return basis points
    }

    /**
     * @dev Update minimum support price for a product category
     */
    function updateMinimumPrice(
        uint256 productId,
        uint128 newMinimumPrice
    ) external onlyRole(PRICE_ORACLE_ROLE) {
        productPricing[productId] = PriceData({
            minimumSupportPrice: newMinimumPrice,
            lastUpdated: uint64(block.timestamp),
            volatilityIndex: _calculateMarketDeviation(newMinimumPrice, globalMinimumPrice),
            marketConfidence: 10000, // 100% confidence
            isActive: true
        });

        emit MinimumPriceUpdated(newMinimumPrice, msg.sender);
    }

    /**
     * @dev Get farmer's current rating and status
     */
    function getFarmerProfile(address farmer) 
        external 
        view 
        returns (
            uint16 currentRating,
            uint32 totalTransactions,
            uint32 penaltyCount,
            bool isActive,
            uint64 lastActivity
        ) 
    {
        FarmerProfile memory profile = farmerProfiles[farmer];
        return (
            profile.currentRating,
            profile.totalTransactions,
            profile.penaltyCount,
            profile.isActive,
            profile.lastActivityTime
        );
    }

    /**
     * @dev Check if a price meets minimum requirements
     */
    function isPriceValid(uint256 productId, uint128 price, address farmer) 
        external 
        view 
        returns (bool) 
    {
        if (!farmerProfiles[farmer].isActive) return false;

        uint128 marketPrice = _getMarketPrice(productId);
        uint128 minimumRequired = _calculateMinimumPrice(productId, farmer, marketPrice);

        return price >= minimumRequired;
    }

    // Admin functions
    function updateGlobalMinimumPrice(uint128 newPrice) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        globalMinimumPrice = newPrice;
        emit MinimumPriceUpdated(newPrice, msg.sender);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }
}
