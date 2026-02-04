/**
 * FILE: functions/index.js
 * Z-KINETIC CLOUD FUNCTIONS (APP CHECK VERIFICATION)
 * FIX: Simplified verification using native Firebase Admin SDK
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const region = 'asia-southeast1';

/**
 * 🚨 UPDATED: Threat Intelligence Processor with App Check Verification
 */
exports.processThreatIntel = functions
  .region(region)
  .firestore
  .document('global_threat_intel/{threatId}')
  .onCreate(async (snap, context) => {
    
    const threatData = snap.data();
    const threatId = context.params.threatId;
    
    console.log('🚨 New threat detected:', { id: threatId, type: threatData.threat_type });
    
    try {
      // 🔥 STEP 1: Verify App Check Token
      if (!threatData.integrity_token) {
        console.warn('⚠️ Missing integrity token. Deleting report.');
        await snap.ref.delete();
        return;
      }
      
      try {
        // ✅ VERIFY GUNA FIREBASE ADMIN (Mudah & Tepat)
        const decodedToken = await admin.appCheck().verifyToken(threatData.integrity_token);
        console.log('✅ App Check Valid. App ID:', decodedToken.appId);
        
      } catch (err) {
        console.error('❌ Invalid App Check Token:', err.message);
        // Delete fake report
        await snap.ref.delete();
        // Flag device
        await blacklistDevice(threatData.device_id || 'UNKNOWN', {
           reason: 'INVALID_APP_CHECK', severity: 'HIGH', incidentId: threatId 
        });
        return;
      }
      
      // 🔥 STEP 2: Token Sah? Teruskan proses...
      await updateGlobalStats(threatData);
      
      if (threatData.severity === 'HIGH' || threatData.severity === 'CRITICAL') {
        await alertBankPartners(threatData, threatId);
      }
      
      // Dashboard analytics
      await db.collection('threat_analytics').add({
        threat_id: threatId,
        threat_type: threatData.threat_type,
        severity: threatData.severity,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        verified: true
      });
      
    } catch (error) {
      console.error('❌ Error processing:', error);
    }
  });

// ... (Functions helper lain: updateGlobalStats, alertBankPartners, blacklistDevice KEKAL SAMA) ...
// Sila copy semula function-function helper tersebut dari kod lama.
// Cuma function verifyPlayIntegrityToken yang lama TU DAH TAK PERLU (boleh buang).

/**
 * Update global threat statistics
 */
async function updateGlobalStats(threatData) {
  const statsRef = db.collection('threat_statistics').doc('global');
  await db.runTransaction(async (transaction) => {
    const statsDoc = await transaction.get(statsRef);
    if (!statsDoc.exists) {
      transaction.set(statsRef, {
        total_threats: 1,
        by_severity: { [threatData.severity]: 1 },
        by_type: { [threatData.threat_type]: 1 },
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      transaction.update(statsRef, {
        total_threats: admin.firestore.FieldValue.increment(1),
        [`by_severity.${threatData.severity}`]: admin.firestore.FieldValue.increment(1),
        [`by_type.${threatData.threat_type}`]: admin.firestore.FieldValue.increment(1),
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}

async function alertBankPartners(threatData, threatId) {
  await db.collection('bank_alerts').add({
    alert_id: `ALERT_${Date.now()}`,
    threat_id: threatId,
    severity: threatData.severity,
    message: `VERIFIED THREAT: ${threatData.threat_type}`,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function blacklistDevice(deviceId, options) {
  await db.collection('blacklisted_devices').doc(deviceId).set({
    deviceId,
    reason: options.reason,
    blacklistedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}
