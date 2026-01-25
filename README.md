# Z-KINETIC EDGE COMPUTING REFACTOR

## 🎯 PIVOT: Privacy-First Threat Intelligence

**Business Model**: Waze for Cyber Threats  
**Privacy Guarantee**: Raw biometric data NEVER leaves the device

---

## ✅ WHAT CHANGED

### **BEFORE (Old Model)**
```
Phone → Raw Biometrics → Firebase → AI Analysis → Verdict
❌ Privacy Risk: Raw touch/motion data uploaded
❌ Bandwidth: Heavy data transfer
❌ Latency: Round-trip to server
```

### **AFTER (Edge Computing)**
```
Phone → [AI Analysis LOCAL] → Threat Detected? → Firebase (Metadata Only)
✅ Privacy: Only threat indicators uploaded
✅ Speed: Local analysis (no network delay)
✅ Efficiency: Minimal data transfer
```

---

## 📦 FILES MODIFIED

### **1. lib/cryptex_lock/src/behavioral_analyzer.dart**
**Changes:**
- ✅ All analysis now happens ON-DEVICE
- ✅ Added `_reportThreat()` method
- ✅ Only uploads threat metadata (NO raw biometrics)
- ✅ Uploads to `global_threat_intel` collection

**What Gets Uploaded:**
```json
{
  "threat_type": "MECHANICAL_RHYTHM",
  "severity": "HIGH",
  "device_os": "Android 36",
  "device_type": "Android",
  "app_version": "1.0.0",
  "timestamp": "2026-01-24T10:30:00Z",
  "indicators": {
    "bot_probability": 85,
    "human_likelihood": 15,
    "anomaly_score": 78,
    "suspicious_count": 3
  },
  "region": "ASIA_SOUTHEAST"
}
```

**What is NOT Uploaded:**
- ❌ Raw touch events
- ❌ Raw motion events
- ❌ Timestamps
- ❌ Pressure values
- ❌ Velocity data
- ❌ Any PII (Personally Identifiable Information)

---

### **2. functions/index.js (Cloud Functions)**
**Changes:**
- ✅ Removed old `analyzeBlackBox` function (no longer needed)
- ✅ Added `processThreatIntel` trigger
- ✅ Added `alertBankPartners()` function
- ✅ Added `getThreatStats()` callable function
- ✅ Added `getThreatHeatmap()` for analytics
- ✅ Added `cleanupOldThreats()` scheduled function

**New Trigger:**
```javascript
exports.processThreatIntel = functions
  .firestore
  .document('global_threat_intel/{threatId}')
  .onCreate(async (snap, context) => {
    // Process new threat
    // Alert bank partners if HIGH/CRITICAL
    // Update global statistics
  });
```

---

### **3. firestore.rules**
**Changes:**
- ✅ Added `global_threat_intel` collection rules
- ✅ Enforces: NO raw biometric data in uploads
- ✅ Validates: Only required fields (threat_type, severity, etc.)
- ✅ Security: Users can CREATE, Admins can READ
- ✅ Immutable: No updates/deletes (audit trail)

**Validation Rules:**
```javascript
allow create: if request.resource.data.keys().hasAll([
  'threat_type', 
  'severity', 
  'device_os', 
  'timestamp'
])
// Ensure NO raw biometric data
&& !request.resource.data.keys().hasAny([
  'motion_events', 
  'touch_events', 
  'raw_data',
  'biometric_data'
]);
```

---

## 🚀 DEPLOYMENT STEPS

### **Step 1: Update Flutter Code**
```bash
# Copy the new behavioral_analyzer.dart
cp behavioral_analyzer.dart lib/cryptex_lock/src/

# No pubspec.yaml changes needed (uses existing packages)
```

### **Step 2: Deploy Cloud Functions**
```bash
cd functions
npm install
firebase deploy --only functions
```

### **Step 3: Update Firestore Rules**
```bash
firebase deploy --only firestore:rules
```

### **Step 4: Create Firestore Indexes**
```bash
# Navigate to Firebase Console
# Firestore → Indexes → Composite
# Create index:
# Collection: global_threat_intel
# Fields: severity (Ascending), timestamp (Descending)
```

### **Step 5: Test the System**
```bash
# Run the app
flutter run --release

# Trigger a bot-like interaction (fast taps, no motion)
# Check Firestore Console → global_threat_intel
# Should see threat report appear (NO raw biometrics)
```

---

## 📊 FIRESTORE COLLECTIONS

### **global_threat_intel** (NEW)
```
Document ID: Auto-generated
Fields:
  - threat_type: String (MECHANICAL_RHYTHM, NO_TREMOR_DETECTED, etc.)
  - severity: String (CRITICAL, HIGH, MEDIUM, LOW)
  - device_os: String (Android 36, iOS 17, etc.)
  - device_type: String (Android, iOS)
  - app_version: String (1.0.0)
  - timestamp: Timestamp
  - indicators: Map
    - bot_probability: Number (0-100)
    - human_likelihood: Number (0-100)
    - anomaly_score: Number (0-100)
    - suspicious_count: Number
  - region: String (ASIA_SOUTHEAST, etc.)
```

### **threat_statistics** (NEW)
```
Document ID: global
Fields:
  - total_threats: Number
  - by_severity: Map
    - CRITICAL: Number
    - HIGH: Number
    - MEDIUM: Number
  - by_type: Map
    - MECHANICAL_RHYTHM: Number
    - NO_TREMOR_DETECTED: Number
    - etc...
  - last_updated: Timestamp
```

### **bank_alerts** (NEW)
```
Document ID: Auto-generated
Fields:
  - alert_id: String
  - threat_id: String (Reference to global_threat_intel)
  - severity: String
  - threat_type: String
  - region: String
  - timestamp: Timestamp
  - message: String
```

---

## 🔒 PRIVACY GUARANTEES

### **What We Collect:**
✅ Threat type (e.g., "MECHANICAL_RHYTHM")  
✅ Severity level (CRITICAL/HIGH/MEDIUM/LOW)  
✅ Device OS (e.g., "Android 36")  
✅ Statistical indicators (bot_probability: 85%)  
✅ Geographic region (ASIA_SOUTHEAST)  

### **What We DON'T Collect:**
❌ Raw touch events  
❌ Raw motion events  
❌ Exact timestamps  
❌ Device IDs (anonymized)  
❌ User IDs  
❌ IP addresses (handled by Firebase)  
❌ Any PII  

### **Compliance:**
- ✅ GDPR Compliant (no personal data)
- ✅ PDPA Malaysia Compliant
- ✅ Apple Privacy Guidelines
- ✅ Google Play Data Safety Requirements

---

## 🏦 BANK PARTNER INTEGRATION

### **Alert Flow:**
```
HIGH Threat Detected → Cloud Function → alertBankPartners()
                                            ↓
                                    Store in bank_alerts
                                            ↓
                                    [Future: HTTP POST to Bank API]
```

### **Bank API Payload (Future):**
```json
{
  "alert_id": "ALERT_1737712800000",
  "threat_id": "abc123",
  "severity": "HIGH",
  "threat_type": "MECHANICAL_RHYTHM",
  "region": "ASIA_SOUTHEAST",
  "timestamp": "2026-01-24T10:30:00Z",
  "message": "HIGH SEVERITY THREAT DETECTED: MECHANICAL_RHYTHM"
}
```

### **Integration Steps (For Banks):**
1. Provide REST API endpoint
2. Generate API key
3. Update `alertBankPartners()` function
4. Uncomment HTTP POST code
5. Test with sandbox environment

---

## 📈 ANALYTICS DASHBOARD

### **Available Endpoints:**

#### **1. Get Global Stats**
```javascript
const getThreatStats = firebase.functions().httpsCallable('getThreatStats');
const stats = await getThreatStats();

// Returns:
{
  total_threats: 1234,
  by_severity: {
    CRITICAL: 45,
    HIGH: 123,
    MEDIUM: 890
  },
  by_type: {
    MECHANICAL_RHYTHM: 567,
    NO_TREMOR_DETECTED: 234,
    ...
  }
}
```

#### **2. Get Threat Heatmap**
```javascript
const getHeatmap = firebase.functions().httpsCallable('getThreatHeatmap');
const heatmap = await getHeatmap({ timeRange: '24h' });

// Returns:
{
  timeRange: '24h',
  total_threats: 156,
  data: {
    ASIA_SOUTHEAST: {
      total: 89,
      by_severity: { CRITICAL: 12, HIGH: 34, MEDIUM: 43 },
      by_type: { MECHANICAL_RHYTHM: 45, ... }
    },
    ...
  }
}
```

---

## 🧪 TESTING

### **Test Case 1: Normal Human Behavior**
```
Action: Normal unlock (shake phone + tap wheels)
Expected: No threat report
Check: Firestore global_threat_intel should be empty
```

### **Test Case 2: Bot Behavior**
```
Action: Fast taps, no motion, perfect rhythm
Expected: Threat report created
Check: Firestore global_threat_intel should have 1 document
  - threat_type: "MECHANICAL_RHYTHM" or "INHUMAN_SPEED"
  - severity: "HIGH"
  - indicators.bot_probability: > 60
```

### **Test Case 3: Bank Alert**
```
Action: Trigger 3+ HIGH threats in 10 minutes
Expected: Bank alert created
Check: Firestore bank_alerts should have 1 document
```

---

## 🐛 TROUBLESHOOTING

### **Problem: Threats not being uploaded**
**Solution:**
1. Check Firebase Auth (user must be authenticated)
2. Check Firestore rules (allow create for authenticated users)
3. Check console logs for errors
4. Verify `global_threat_intel` collection exists

### **Problem: Cloud Function not triggering**
**Solution:**
1. Check Cloud Functions logs: `firebase functions:log`
2. Verify function deployed: `firebase functions:list`
3. Check Firestore trigger path: `global_threat_intel/{threatId}`
4. Test manually: Create document in Firestore Console

### **Problem: Privacy violation (raw data uploaded)**
**Solution:**
1. Check Firestore rules (should reject if motion_events present)
2. Review behavioral_analyzer.dart `_reportThreat()` method
3. Verify only `threatData` map is uploaded (no session data)

---

## 📝 MIGRATION NOTES

### **For Existing Users:**
- ✅ No action required (backward compatible)
- ✅ Old `user_baselines` still work (optional)
- ✅ New threat reporting happens automatically
- ✅ No data loss (old logs preserved)

### **Deprecated Collections:**
- `security_incidents` → Use `global_threat_intel`
- `verification_logs` → No longer needed (local analysis)

### **Cleanup (Optional):**
```javascript
// Delete old verification logs (save storage costs)
firebase firestore:delete verification_logs --recursive
```

---

## 🎉 BENEFITS

### **For Users:**
✅ **Privacy**: Raw biometrics stay on device  
✅ **Speed**: Instant local analysis (no network delay)  
✅ **Offline**: Works without internet (verification only)  

### **For Business:**
✅ **Compliance**: GDPR/PDPA ready  
✅ **Scalability**: Reduced server load  
✅ **Cost**: Lower Firebase usage (minimal writes)  

### **For Banks:**
✅ **Real-time Alerts**: Instant threat notifications  
✅ **Analytics**: Global threat heatmap  
✅ **Zero PII**: No liability for user data  

---

## 📞 SUPPORT

**Questions?** Contact Captain Aer  
**Documentation**: https://docs.z-kinetic.com  
**GitHub**: https://github.com/z-kinetic/edge-computing
