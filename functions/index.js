/**
 * FILE: functions/index.js
 * Z-KINETIC CLOUD FUNCTIONS (APP CHECK VERIFICATION + NONCE PROTECTION)
 * POLISHED VERSION: Device-based rate limiting + Replay attack prevention
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const region = 'asia-southeast1';

/**
 * 🚨 MAIN PROCESSOR: Threat Intelligence with App Check + Nonce Verification
 */
exports.processThreatIntel = functions
  .region(region)
  .firestore
  .document('global_threat_intel/{threatId}')
  .onCreate(async (snap, context) => {
    
    const threatData = snap.data();
    const threatId = context.params.threatId;
    
    console.log('🚨 New threat detected:', { 
      id: threatId, 
      type: threatData.threat_type,
      device: threatData.device_id 
    });
    
    try {
      // ============================================
      // STEP 1: Verify App Check Token
      // ============================================
      if (!threatData.integrity_token) {
        console.warn('⚠️ Missing integrity token. Deleting report.');
        await snap.ref.delete();
        return;
      }
      
      try {
        const decodedToken = await admin.appCheck().verifyToken(threatData.integrity_token);
        console.log('✅ App Check Valid. App ID:', decodedToken.appId);
        
      } catch (err) {
        console.error('❌ Invalid App Check Token:', err.message);
        await snap.ref.delete();
        await blacklistDevice(threatData.device_id || 'UNKNOWN', {
          reason: 'INVALID_APP_CHECK', 
          severity: 'HIGH', 
          incidentId: threatId 
        });
        return;
      }
      
      // ============================================
      // STEP 2: Check Nonce (Prevent Replay Attacks)
      // ============================================
      const nonceKey = `${threatData.device_id}:${threatData.session_id}`;
      const nonceRef = db.collection('used_nonces').doc(nonceKey);
      const nonceDoc = await nonceRef.get();
      
      if (nonceDoc.exists) {
        console.warn('⚠️ Duplicate nonce detected (replay attack):', nonceKey);
        await snap.ref.delete();
        await blacklistDevice(threatData.device_id, {
          reason: 'REPLAY_ATTACK',
          severity: 'CRITICAL',
          incidentId: threatId
        });
        return;
      }
      
      // Mark nonce as used (expires in 1 hour)
      await nonceRef.set({
        used_at: admin.firestore.FieldValue.serverTimestamp(),
        threat_id: threatId,
        expires_at: new Date(Date.now() + 3600000) // 1 hour
      });
      
      // ============================================
      // STEP 3: Update Rate Limit Timestamp
      // ============================================
      await db.collection('rate_limits').doc(threatData.device_id).set({
        last_report: admin.firestore.FieldValue.serverTimestamp(),
        device_id: threatData.device_id
      }, { merge: true });
      
      // ============================================
      // STEP 4: Process Verified Threat
      // ============================================
      await updateGlobalStats(threatData);
      
      if (threatData.severity === 'HIGH' || threatData.severity === 'CRITICAL') {
        await alertBankPartners(threatData, threatId);
      }
      
      // Dashboard analytics
      await db.collection('threat_analytics').add({
        threat_id: threatId,
        threat_type: threatData.threat_type,
        severity: threatData.severity,
        device_id: threatData.device_id,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        verified: true
      });
      
      console.log('✅ Threat processed successfully:', threatId);
      
    } catch (error) {
      console.error('❌ Error processing threat:', error);
    }
  });

/**
 * 🧹 SCHEDULED CLEANUP: Remove expired nonces (runs every hour)
 */
exports.cleanupExpiredNonces = functions
  .region(region)
  .pubsub
  .schedule('0 * * * *') // Every hour at :00
  .timeZone('Asia/Kuala_Lumpur')
  .onRun(async (context) => {
    
    console.log('🧹 Starting nonce cleanup...');
    
    const now = admin.firestore.Timestamp.now();
    const expiredNonces = await db.collection('used_nonces')
      .where('expires_at', '<', now.toDate())
      .limit(500)
      .get();
    
    if (expiredNonces.empty) {
      console.log('✅ No expired nonces to clean');
      return null;
    }
    
    const batch = db.batch();
    let count = 0;
    
    expiredNonces.forEach(doc => {
      batch.delete(doc.ref);
      count++;
    });
    
    await batch.commit();
    console.log(`✅ Deleted ${count} expired nonces`);
    
    return null;
  });

// ============================================
// HELPER FUNCTIONS
// ============================================

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

/**
 * Alert bank partners about critical threats
 */
async function alertBankPartners(threatData, threatId) {
  await db.collection('bank_alerts').add({
    alert_id: `ALERT_${Date.now()}`,
    threat_id: threatId,
    threat_type: threatData.threat_type,
    severity: threatData.severity,
    device_id: threatData.device_id,
    message: `VERIFIED THREAT: ${threatData.threat_type}`,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    requires_action: true
  });
  
  console.log('🚨 Bank alert created for threat:', threatId);
}

/**
 * Blacklist malicious device
 */
async function blacklistDevice(deviceId, options) {
  await db.collection('blacklisted_devices').doc(deviceId).set({
    device_id: deviceId,
    reason: options.reason,
    severity: options.severity || 'MEDIUM',
    incident_id: options.incidentId || null,
    blacklisted_at: admin.firestore.FieldValue.serverTimestamp(),
    auto_generated: true
  }, { merge: true });
  
  console.log('🚫 Device blacklisted:', deviceId, '| Reason:', options.reason);
}
