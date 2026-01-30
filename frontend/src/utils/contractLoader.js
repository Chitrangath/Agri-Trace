/**
 * Contract ABI Loader
 * This utility loads contract ABIs from the out directory
 * In production, you would copy ABIs to frontend/src/abis/
 */

// Import ABIs - These will be generated after forge build
// For now, we'll use a placeholder structure

export const loadContractABI = async (contractName) => {
  try {
    // In production, load from src/abis/ directory
    const response = await fetch(`/abis/${contractName}.json`);
    if (response.ok) {
      const abi = await response.json();
      return abi.abi || abi;
    }
  } catch (error) {
    console.warn(`Could not load ABI for ${contractName}, using minimal interface`);
  }
  
  // Fallback: Return minimal interface for common functions
  return getMinimalABI(contractName);
};

const getMinimalABI = (contractName) => {
  const minimalABIs = {
    ConsumerInterface: [
      "function verifyProduct(uint256 productId) external returns (tuple(uint256 productId, address farmer, uint96 currentPrice, uint64 harvestTime, uint32 quantity, uint16 qualityScore, uint8 currentStage, bool isAuthentic) memory)",
      "function verifyByQRCode(bytes32 qrHash) external returns (tuple(bool isValid, string status, uint256 productId, string farmerName, uint256 rating) memory)",
      "function getFarmerReputation(address farmer) external view returns (tuple(address farmerAddress, uint64 registrationDate, uint32 totalSales, uint16 trustScore, bool isVerified) memory)",
      "function batchVerifyProducts(uint256[] calldata productIds) external view returns (tuple(uint256 productId, address farmer, uint96 currentPrice, uint64 harvestTime, uint32 quantity, uint16 qualityScore, uint8 currentStage, bool isAuthentic)[] memory)",
      "function getProductJourney(uint256 productId) external view returns (string[] memory stages, uint256[] memory timestamps, uint256[] memory qualityScores)",
      "function getProductMetrics(uint256 productId) external view returns (uint256 views, string[] memory certifications)",
      "function productNames(uint256) external view returns (string memory)",
      "function farmerNames(address) external view returns (string memory)"
    ],
    AgricultureSupplyChain: [
      "function getProduct(uint256 productId) external view returns (uint128 id, uint64 timestamp, uint32 quantity, uint96 price, address owner, uint8 stage)",
      "function getQualityHistory(uint256 productId) external view returns (tuple(uint64 timestamp, uint32 temperature, uint32 humidity, uint16 qualityScore, bytes32 certificationHash)[] memory qualities, string[] memory ipfsHashes)",
      "function getProductIPFSHashes(uint256 productId) external view returns (string[] memory)",
      "function createProduct(uint32 quantity, uint96 price, bytes32 locationHash, string[] calldata ipfsHashes) external returns (uint256)",
      "function updateProductStage(uint256 productId, uint8 newStage) external",
      "function addQualityData(uint256 productId, uint32 temperature, uint32 humidity, uint16 qualityScore, bytes32 certificationHash, string calldata ipfsHash) external",
      "function transferOwnership(uint256 productId, address newOwner, uint96 newPrice) external",
      "function ownerProducts(address) external view returns (uint256[] memory)"
    ],
    QRCodeRegistry: [
      "function registerQRCode(bytes32 qrHash, uint32 productId, string calldata ipfsMetadataHash) external returns (bool)",
      "function getProductFromQR(bytes32 qrHash) external view returns (uint256)",
      "function isQRCodeActive(bytes32 qrHash) external view returns (bool)",
      "function getQRData(bytes32 qrHash) external view returns (uint256 productId, address creator, uint64 timestamp, bool active, string memory ipfsHash)",
      "function getUserQRCodes(address user) external view returns (bytes32[] memory)"
    ],
    PaymentContract: [
      "function createPayment(uint96 amount, address payee, uint64 dueDate, bytes32 conditionsHash) external payable returns (uint256)",
      "function executePayment(uint256 paymentId) external",
      "function cancelPayment(uint256 paymentId) external",
      "function depositFunds() external payable",
      "function withdrawFunds(uint256 amount) external",
      "function getPaymentStatus(uint256 paymentId) external view returns (string memory)",
      "function getAvailableBalance(address account) external view returns (uint256)",
      "function payments(uint256) external view returns (address payee, uint96 amount, address payer, uint64 dueDate, uint8 status, bytes32 conditionsHash)"
    ],
    FairPricingContract: [
      "function registerFarmer(address farmer) external returns (bool)",
      "function validateProductPricing(uint256 productId, uint128 proposedPrice, address farmer) external returns (bool)",
      "function getFarmerProfile(address farmer) external view returns (uint16 currentRating, uint32 totalTransactions, uint32 penaltyCount, bool isActive, uint64 lastActivity)",
      "function isPriceValid(uint256 productId, uint128 price, address farmer) external view returns (bool)",
      "function updateGlobalMinimumPrice(uint128 newPrice) external"
    ],
    FraudDetectionContract: [
      "function analyzePriceAnomaly(uint256 productId) external returns (uint256 anomalyId)",
      "function validateStageTimings(uint256 productId) external returns (uint256 violationId)",
      "function comprehensiveFraudAnalysis(uint256 productId) external returns (uint32 riskScore, string[] memory detectedIssues)",
      "function getAnomalyDetails(uint256 anomalyId) external view returns (tuple(uint256 productId, uint128 suspiciousPrice, uint64 detectionTime, uint32 deviationPercentage, uint16 confidenceScore, uint8 anomalyType, bool isResolved))",
      "function isActorBlacklisted(address actor) external view returns (bool)"
    ]
  };
  
  return minimalABIs[contractName] || [];
};
