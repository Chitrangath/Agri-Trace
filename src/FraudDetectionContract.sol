
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

/**
 * @title FraudDetectionContract
 * @dev Advanced fraud detection with price anomaly and time validation
 * @dev Uses statistical methods and pattern recognition for fraud prevention
 */
contract FraudDetectionContract is AccessControl, ReentrancyGuard, Pausable {
    error SuspiciousActivity();
    error InvalidTimeValidation(); 
    error FraudAnomalyDetected();
    error InsufficientHistoricalData();
    error UnauthorizedAnalysis();

    bytes32 public constant FRAUD_ANALYST_ROLE = keccak256("FRAUD_ANALYST_ROLE");
    bytes32 public constant AUTOMATED_DETECTOR_ROLE = keccak256("AUTOMATED_DETECTOR_ROLE");

    // Gas optimized fraud detection data structures
    struct PriceAnomaly {
        uint256 productId;             // 32 bytes - slot 0
        uint128 suspiciousPrice;       // 16 bytes - slot 1
        uint64 detectionTime;         // 8 bytes - fits in slot 1
        uint32 deviationPercentage;   // 4 bytes - fits in slot 1
        uint16 confidenceScore;       // 2 bytes - fits in slot 1
        uint8 anomalyType;            // 1 byte - fits in slot 1 (31 bytes used)
        bool isResolved;              // 1 bit - uses next slot due to packing
    }

    struct TimeViolation {
        uint256 productId;            // 32 bytes - slot 0
        uint64 expectedTime;          // 8 bytes - slot 1
        uint64 actualTime;            // 8 bytes - fits in slot 1
        uint32 delayMinutes;          // 4 bytes - fits in slot 1
        uint8 stageViolated;          // 1 byte - fits in slot 1
        uint8 violationType;          // 1 byte - fits in slot 1
        bool isResolved;              // 1 byte - fits in slot 1 (25 bytes used)
    }

    struct FraudPattern {
        address suspiciousActor;      // 20 bytes - slot 0
        uint64 firstDetection;        // 8 bytes - fits in slot 0
        uint32 violationCount;        // 4 bytes - fits in slot 0 (32 bytes total)
        uint128 totalSuspiciousValue; // 16 bytes - slot 1
        uint64 lastViolation;         // 8 bytes - fits in slot 1
        uint32 riskScore;             // 4 bytes - fits in slot 1
        bool isBlacklisted;           // 1 byte - fits in slot 1 (29 bytes used)
    }

    // Historical data for statistical analysis
    struct PriceHistory {
        uint128 price;                // 16 bytes - slot 0
        uint64 timestamp;             // 8 bytes - fits in slot 0
        uint32 productId;             // 4 bytes - fits in slot 0
        uint8 stage;                  // 1 byte - fits in slot 0 (29 bytes used)
    }

    // Detection parameters (configurable)
    struct DetectionConfig {
        uint32 priceDeviationThreshold;      // Basis points (e.g., 2000 = 20%)
        uint32 timeDeviationThresholdMinutes; // Minutes allowed for stage transitions
        uint16 minimumHistoryRequired;        // Minimum data points needed
        uint16 confidenceThreshold;           // Minimum confidence for fraud flagging
        uint8 maxViolationsBeforeBlacklist;  // Max violations before blacklisting
        bool isActive;                        // Enable/disable detection
    }

    IAgricultureSupplyChain public immutable supplyChainContract;

    mapping(uint256 => PriceAnomaly) public detectedAnomalies;
    mapping(uint256 => TimeViolation) public timeViolations;
    mapping(address => FraudPattern) public fraudPatterns;
    mapping(uint256 => PriceHistory[]) public priceHistories; // productId => price history
    mapping(uint8 => uint64) public stageTimeExpectations; // stage => expected duration in minutes

    DetectionConfig public config;
    uint256 public anomalyCounter;
    uint256 public violationCounter;

    // Statistical tracking
    mapping(uint256 => uint128) public rollingPriceAverage; // productId => average price
    mapping(uint256 => uint128) public priceStandardDeviation; // productId => std deviation
    mapping(address => uint256[]) public actorTransactionHistory; // actor => product IDs

    event AnomalyDetected(uint256 indexed anomalyId, uint256 indexed productId, string anomalyType, uint256 confidence);
    event TimeViolationDetected(uint256 indexed violationId, uint256 indexed productId, uint256 delay);
    event FraudPatternIdentified(address indexed actor, uint256 riskScore, string patternType);
    event ActorBlacklisted(address indexed actor, string reason);
    event FraudResolved(uint256 indexed caseId, address resolver, string resolution);

    modifier onlyAnalyst() {
        if (!hasRole(FRAUD_ANALYST_ROLE, msg.sender)) revert UnauthorizedAnalysis();
        _;
    }

    modifier detectionActive() {
        require(config.isActive, "Detection disabled");
        _;
    }

    constructor(address _supplyChainContract) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FRAUD_ANALYST_ROLE, msg.sender);
        _grantRole(AUTOMATED_DETECTOR_ROLE, msg.sender);

        supplyChainContract = IAgricultureSupplyChain(_supplyChainContract);

        // Initialize default detection configuration
        config = DetectionConfig({
            priceDeviationThreshold: 3000,        // 30% price deviation
            timeDeviationThresholdMinutes: 1440,  // 24 hours maximum delay
            minimumHistoryRequired: 5,            // Need 5 data points minimum
            confidenceThreshold: 7500,            // 75% confidence threshold
            maxViolationsBeforeBlacklist: 3,      // 3 strikes rule
            isActive: true
        });

        // Set expected stage durations (in minutes)
        stageTimeExpectations[0] = 10080;  // Planted: 7 days
        stageTimeExpectations[1] = 129600; // Growing: 90 days
        stageTimeExpectations[2] = 1440;   // Harvested: 1 day
        stageTimeExpectations[3] = 2880;   // Processed: 2 days
        stageTimeExpectations[4] = 720;    // Packaged: 12 hours
        stageTimeExpectations[5] = 4320;   // InTransit: 3 days
        stageTimeExpectations[6] = 1440;   // Distributed: 1 day
        stageTimeExpectations[7] = 10080;  // Retail: 7 days
    }

    /**
     * @dev Analyze product for price anomalies using statistical methods
     * @param productId Product to analyze
     * @return anomalyId ID of detected anomaly (0 if none)
     */
    function analyzePriceAnomaly(uint256 productId) 
        external 
        nonReentrant 
        detectionActive
        returns (uint256 anomalyId) 
    {
        // Get current product data
        (,, uint32 quantity, uint96 price, address owner, uint8 stage) = 
            supplyChainContract.getProduct(productId);

        if (price == 0) return 0;

        // Update price history
        _updatePriceHistory(productId, price, stage);

        // Check if we have sufficient history for analysis
        if (priceHistories[productId].length < config.minimumHistoryRequired) {
            return 0;
        }

        // Calculate statistical anomaly
        (bool isAnomaly, uint32 deviationPercentage, uint8 anomalyType) = 
            _detectStatisticalAnomaly(productId, price);

        if (isAnomaly) {
            anomalyId = ++anomalyCounter;

            detectedAnomalies[anomalyId] = PriceAnomaly({
                productId: productId,
                suspiciousPrice: price,
                detectionTime: uint64(block.timestamp),
                deviationPercentage: deviationPercentage,
                confidenceScore: _calculateConfidenceScore(productId, price),
                anomalyType: anomalyType,
                isResolved: false
            });

            // Update fraud pattern for the actor
            _updateFraudPattern(owner, price, anomalyId);

            emit AnomalyDetected(
                anomalyId, 
                productId, 
                _getAnomalyTypeString(anomalyType),
                detectedAnomalies[anomalyId].confidenceScore
            );
        }

        return anomalyId;
    }

    /**
     * @dev Validate timing between supply chain stages
     * @param productId Product to validate
     * @return violationId ID of detected violation (0 if none)
     */
    function validateStageTimings(uint256 productId) 
        external 
        nonReentrant 
        detectionActive
        returns (uint256 violationId) 
    {
        (,uint64 timestamp,, uint96 price, address owner, uint8 currentStage) = 
            supplyChainContract.getProduct(productId);

        if (currentStage == 0) return 0; // No previous stage to validate

        // Get expected time for previous stage
        uint8 previousStage = currentStage - 1;
        uint64 expectedDuration = stageTimeExpectations[previousStage];

        // Calculate actual duration (simplified - assumes linear progression)
        uint256 timeDiff = block.timestamp - timestamp;
        uint64 actualDuration = uint64(timeDiff / 60); // Convert to minutes

        // Check for significant time violations
        if (actualDuration > expectedDuration + config.timeDeviationThresholdMinutes) {
            violationId = ++violationCounter;
            uint32 delayMinutes = uint32(actualDuration - expectedDuration);

            timeViolations[violationId] = TimeViolation({
                productId: productId,
                expectedTime: timestamp + (expectedDuration * 60),
                actualTime: uint64(block.timestamp),
                delayMinutes: delayMinutes,
                stageViolated: currentStage,
                violationType: 1, // Time delay violation
                isResolved: false
            });

            // Update fraud pattern
            _updateFraudPattern(owner, price, violationId);

            emit TimeViolationDetected(violationId, productId, delayMinutes);
        }

        return violationId;
    }

    /**
     * @dev Comprehensive fraud analysis combining multiple detection methods
     * @param productId Product to analyze comprehensively
     * @return riskScore Overall risk score (0-10000, higher = more risky)
     * @return detectedIssues Array of issue descriptions
     */
    function comprehensiveFraudAnalysis(uint256 productId) 
        external 
        nonReentrant 
        detectionActive
        returns (uint32 riskScore, string[] memory detectedIssues) 
    {
        uint256 priceAnomalyId = this.analyzePriceAnomaly(productId);
        uint256 timeViolationId = this.validateStageTimings(productId);

        // Calculate combined risk score
        riskScore = 0;
        uint256 issueCount = 0;
        string[] memory issues = new string[](3); // Maximum possible issues

        if (priceAnomalyId > 0) {
            riskScore += 4000; // Price anomaly adds significant risk
            issues[issueCount] = "Price anomaly detected";
            issueCount++;
        }

        if (timeViolationId > 0) {
            riskScore += 3000; // Time violation adds moderate risk
            issues[issueCount] = "Timing violation detected";
            issueCount++;
        }

        // Check historical pattern
        (,, uint32 quantity, uint96 price, address owner, uint8 stage) = 
            supplyChainContract.getProduct(productId);

        FraudPattern memory pattern = fraudPatterns[owner];
        if (pattern.violationCount >= 2) {
            riskScore += pattern.riskScore;
            issues[issueCount] = "Historical fraud pattern detected";
            issueCount++;
        }

        // Resize array to actual issue count
        detectedIssues = new string[](issueCount);
        for (uint256 i = 0; i < issueCount; i++) {
            detectedIssues[i] = issues[i];
        }

        // Auto-blacklist if risk score is too high
        if (riskScore >= 8000 && !pattern.isBlacklisted) {
            _blacklistActor(owner, "High fraud risk score");
        }

        return (riskScore, detectedIssues);
    }

    /**
     * @dev Internal function to detect statistical price anomalies
     */
    function _detectStatisticalAnomaly(uint256 productId, uint96 currentPrice) 
        internal 
        view 
        returns (bool isAnomaly, uint32 deviationPercentage, uint8 anomalyType) 
    {
        PriceHistory[] memory history = priceHistories[productId];
        if (history.length < config.minimumHistoryRequired) {
            return (false, 0, 0);
        }

        // Calculate rolling average and standard deviation
        uint256 sum = 0;
        for (uint256 i = 0; i < history.length; i++) {
            sum += history[i].price;
        }
        uint128 average = uint128(sum / history.length);

        // Calculate standard deviation
        uint256 varianceSum = 0;
        for (uint256 i = 0; i < history.length; i++) {
            uint256 diff = history[i].price > average ? 
                history[i].price - average : average - history[i].price;
            varianceSum += diff * diff;
        }
        uint128 standardDev = uint128(sqrt(varianceSum / history.length));

        // Detect anomaly using z-score method (simplified)
        uint128 deviation = currentPrice > average ? 
            currentPrice - average : average - currentPrice;

        deviationPercentage = average > 0 ? uint32((deviation * 10000) / average) : 0;

        // Classify anomaly type
        if (deviationPercentage > config.priceDeviationThreshold) {
            if (currentPrice > average + (2 * standardDev)) {
                anomalyType = 1; // Suspiciously high price
            } else if (currentPrice < average - (2 * standardDev)) {
                anomalyType = 2; // Suspiciously low price
            } else {
                anomalyType = 3; // General price anomaly
            }
            isAnomaly = true;
        }

        return (isAnomaly, deviationPercentage, anomalyType);
    }

    /**
     * @dev Update price history for statistical analysis
     */
    function _updatePriceHistory(uint256 productId, uint96 price, uint8 stage) internal {
        priceHistories[productId].push(PriceHistory({
            price: price,
            timestamp: uint64(block.timestamp),
            productId: uint32(productId),
            stage: stage
        }));

        // Limit history size to prevent unbounded growth
        if (priceHistories[productId].length > 100) {
            // Remove oldest entry (gas-expensive but necessary)
            for (uint256 i = 0; i < priceHistories[productId].length - 1; i++) {
                priceHistories[productId][i] = priceHistories[productId][i + 1];
            }
            priceHistories[productId].pop();
        }
    }

    /**
     * @dev Update fraud pattern for an actor
     */
    function _updateFraudPattern(address actor, uint96 suspiciousValue, uint256 caseId) internal {
        FraudPattern storage pattern = fraudPatterns[actor];

        if (pattern.suspiciousActor == address(0)) {
            // First violation
            pattern.suspiciousActor = actor;
            pattern.firstDetection = uint64(block.timestamp);
            pattern.violationCount = 1;
            pattern.totalSuspiciousValue = suspiciousValue;
            pattern.lastViolation = uint64(block.timestamp);
            pattern.riskScore = 1000; // Initial risk score
        } else {
            // Subsequent violations
            pattern.violationCount++;
            pattern.totalSuspiciousValue += suspiciousValue;
            pattern.lastViolation = uint64(block.timestamp);
            pattern.riskScore += 1500; // Escalating risk

            // Check blacklist threshold
            if (pattern.violationCount >= config.maxViolationsBeforeBlacklist) {
                _blacklistActor(actor, "Exceeded maximum violations");
            }
        }

        emit FraudPatternIdentified(actor, pattern.riskScore, "Suspicious activity pattern");
    }

    /**
     * @dev Blacklist an actor for fraudulent behavior
     */
    function _blacklistActor(address actor, string memory reason) internal {
        fraudPatterns[actor].isBlacklisted = true;
        emit ActorBlacklisted(actor, reason);
    }

    /**
     * @dev Calculate confidence score for anomaly detection
     */
    function _calculateConfidenceScore(uint256 productId, uint96 price) 
        internal 
        view 
        returns (uint16) 
    {
        // Simplified confidence calculation based on historical data quality
        uint256 historyLength = priceHistories[productId].length;
        if (historyLength >= 20) return 9000; // High confidence
        if (historyLength >= 10) return 7500; // Medium confidence
        return 5000; // Low confidence
    }

    /**
     * @dev Convert anomaly type to string
     */
    function _getAnomalyTypeString(uint8 anomalyType) internal pure returns (string memory) {
        if (anomalyType == 1) return "Suspiciously high price";
        if (anomalyType == 2) return "Suspiciously low price";
        if (anomalyType == 3) return "General price anomaly";
        return "Unknown anomaly";
    }

    /**
     * @dev Simple integer square root function
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    // View functions
    function getAnomalyDetails(uint256 anomalyId) 
        external 
        view 
        returns (PriceAnomaly memory) 
    {
        return detectedAnomalies[anomalyId];
    }

    function getViolationDetails(uint256 violationId) 
        external 
        view 
        returns (TimeViolation memory) 
    {
        return timeViolations[violationId];
    }

    function getFraudPattern(address actor) 
        external 
        view 
        returns (FraudPattern memory) 
    {
        return fraudPatterns[actor];
    }

    function isActorBlacklisted(address actor) external view returns (bool) {
        return fraudPatterns[actor].isBlacklisted;
    }

    // Admin functions
    function updateDetectionConfig(DetectionConfig calldata newConfig) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        config = newConfig;
    }

    function resolveAnomaly(uint256 anomalyId, string calldata resolution) 
        external 
        onlyAnalyst 
    {
        detectedAnomalies[anomalyId].isResolved = true;
        emit FraudResolved(anomalyId, msg.sender, resolution);
    }

    function resolveViolation(uint256 violationId, string calldata resolution) 
        external 
        onlyAnalyst 
    {
        timeViolations[violationId].isResolved = true;
        emit FraudResolved(violationId, msg.sender, resolution);
    }

    function removeBlacklist(address actor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fraudPatterns[actor].isBlacklisted = false;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }
}
