# Frontend Migration Guide

## ⚠️ Breaking Changes for Frontend

Your frontend at [https://68d1c22dbc928db43b9cbdbf--agri-trace.netlify.app/](https://68d1c22dbc928db43b9cbdbf--agri-trace.netlify.app/) will need updates to work with the new contract versions.

## 🔴 Critical Breaking Change

### `getQualityHistory()` Return Type Changed

**OLD (Previous Version):**
```solidity
function getQualityHistory(uint256 productId) 
    external view 
    returns (uint256[] memory qualities, string[] memory ipfsHashes)
```

**NEW (Current Version):**
```solidity
function getQualityHistory(uint256 productId) 
    external view 
    returns (QualityData[] memory qualities, string[] memory ipfsHashes)
```

Where `QualityData` is a struct:
```solidity
struct QualityData {
    uint64 timestamp;
    uint32 temperature;
    uint32 humidity;
    uint16 qualityScore;
    bytes32 certificationHash;
}
```

## ✅ What Still Works (No Changes Needed)

These functions remain **unchanged** and will work without frontend updates:

1. **ConsumerInterface.verifyProduct()** - Returns `ProductSummary` (same structure)
2. **ConsumerInterface.verifyByQRCode()** - Returns `VerificationResult` (same structure)
3. **ConsumerInterface.getFarmerReputation()** - Returns `FarmerReputation` (same structure)
4. **ConsumerInterface.batchVerifyProducts()** - Returns `ProductSummary[]` (same structure)
5. **AgricultureSupplyChain.getProduct()** - Returns same tuple
6. **QRCodeRegistry** functions - All unchanged
7. **PaymentContract** functions - All unchanged (internal changes only)

## 🔧 Required Frontend Updates

### If You're Calling `getQualityHistory()` Directly

**Before:**
```javascript
const [qualities, ipfsHashes] = await contract.getQualityHistory(productId);
// qualities was: uint256[]
// Access: qualities[0] (just a number)
```

**After:**
```javascript
const [qualities, ipfsHashes] = await contract.getQualityHistory(productId);
// qualities is now: QualityData[]
// Access: qualities[0].qualityScore, qualities[0].temperature, etc.

// Example usage:
qualities.forEach(quality => {
    console.log('Quality Score:', quality.qualityScore);
    console.log('Temperature:', quality.temperature);
    console.log('Humidity:', quality.humidity);
    console.log('Timestamp:', quality.timestamp);
    console.log('Certification:', quality.certificationHash);
});
```

### TypeScript Interface Update

If using TypeScript, update your interface:

```typescript
// OLD
interface QualityHistory {
    qualities: bigint[];  // uint256[]
    ipfsHashes: string[];
}

// NEW
interface QualityData {
    timestamp: bigint;      // uint64
    temperature: number;   // uint32
    humidity: number;       // uint32
    qualityScore: number;   // uint16
    certificationHash: string; // bytes32
}

interface QualityHistory {
    qualities: QualityData[];
    ipfsHashes: string[];
}
```

### Ethers.js / Web3.js Example

```javascript
// Get quality history
const [qualities, ipfsHashes] = await supplyChainContract.getQualityHistory(productId);

// Access quality data
if (qualities.length > 0) {
    const latestQuality = qualities[qualities.length - 1];
    
    // Convert from BigNumber if using ethers.js
    const qualityScore = latestQuality.qualityScore.toString();
    const temperature = latestQuality.temperature.toString();
    const humidity = latestQuality.humidity.toString();
    const timestamp = latestQuality.timestamp.toString();
    
    console.log(`Latest Quality Score: ${qualityScore}`);
    console.log(`Temperature: ${temperature}°C`);
    console.log(`Humidity: ${humidity}%`);
}
```

## 📋 Migration Checklist

- [ ] **Update contract ABIs** - Regenerate from new contracts
- [ ] **Update `getQualityHistory()` calls** - Change from `uint256[]` to `QualityData[]`
- [ ] **Update TypeScript interfaces** - Add `QualityData` struct type
- [ ] **Update quality display logic** - Access struct fields instead of array values
- [ ] **Test quality history display** - Verify new data structure renders correctly
- [ ] **Update contract addresses** - Use new deployed addresses after Sepolia deployment

## 🎯 Recommended Approach

### Option 1: Use ConsumerInterface (Easiest - No Changes Needed!)

If your frontend uses `ConsumerInterface.verifyProduct()`, you don't need any changes! The ConsumerInterface handles the quality data internally and returns a simple `ProductSummary` with just the `qualityScore`.

```javascript
// This still works exactly the same!
const summary = await consumerInterface.verifyProduct(productId);
console.log(summary.qualityScore); // Still works!
```

### Option 2: Update Direct Calls

If you're calling `AgricultureSupplyChain.getQualityHistory()` directly, update to handle the new struct format.

## 🔍 How to Check What Your Frontend Uses

1. **Search your codebase for:**
   - `getQualityHistory`
   - `qualityHistory`
   - Direct calls to `AgricultureSupplyChain`

2. **Check your contract interactions:**
   - Are you using `ConsumerInterface`? ✅ No changes needed
   - Are you calling `AgricultureSupplyChain` directly? ⚠️ Needs updates

## 📝 Example Frontend Code Update

### Before:
```javascript
// OLD - Direct array access
const [scores, hashes] = await supplyChain.getQualityHistory(id);
const latestScore = scores[scores.length - 1]; // Just a number
```

### After:
```javascript
// NEW - Struct access
const [qualities, hashes] = await supplyChain.getQualityHistory(id);
const latestQuality = qualities[qualities.length - 1];
const latestScore = latestQuality.qualityScore; // Access struct field
const temp = latestQuality.temperature;
const humidity = latestQuality.humidity;
```

## 🚀 Testing Your Updates

1. **Deploy new contracts to Sepolia**
2. **Update frontend contract addresses**
3. **Test quality history display**
4. **Verify all ConsumerInterface functions still work**

## 💡 Benefits of the Change

The new structure provides **more information**:
- ✅ Temperature data
- ✅ Humidity data  
- ✅ Timestamps for each quality check
- ✅ Certification hashes
- ✅ Better data structure for UI display

## 📞 Need Help?

If you encounter issues:
1. Check the contract ABIs match the new versions
2. Verify contract addresses are updated
3. Check browser console for decoding errors
4. Review the new `QualityData` struct format

---

**Summary**: If you're using `ConsumerInterface`, no changes needed! If calling `getQualityHistory()` directly, update to handle `QualityData[]` structs instead of `uint256[]`.
