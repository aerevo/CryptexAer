/**
 * FILE: functions/index.js
 * Z-KINETIC CLOUD FUNCTIONS (EDGE COMPUTING MODEL)
 * 🔥 UPDATED: Play Integrity token verification
 * PURPOSE: Process threat intelligence reports (NO RAW BIOMETRICS)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
// 🔥 NEW: Google Cloud reCAPTCHA Enterprise for token verification
const { RecaptchaEnterpriseServiceClient } = require('@google-cloud/recaptcha-enterprise');

admin.initializeApp();

const db = admin.firestore();
const region = 'asia-southeast1';

// 🔥 NEW: Initialize reCAPTCHA client
const recaptchaClient = new RecaptchaEnterpriseServiceClient();
const projectPath = recaptchaClient.projectPath('55621733629'); // Z-Kinetic project ID

/**
 * 🚨 UPDATED: Threat Intelligence Processor with Token Verification
 * Triggered when new threat is reported to global_threat_intel
 * NO RAW BIOMETRIC DATA - Only statistical indicators
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
      severity: threatData.severity,
      device_os: threatData.device_os,
      has_token: threatData.has_integrity_token,
    });
    
    try {
      // 🔥 STEP 1: Verify Play Integrity Token
      if (!threatData.integrity_token || !threatData.has_integrity_token) {
        console.warn('⚠️ Threat report missing integrity token:', threatId);
        
        // Delete unverified report (strict mode)
        await snap.ref.delete();
        
        // Flag suspicious activity
        await flagSuspiciousActivity(threatData.device_id || 'UNKNOWN', 'MISSING_INTEGRITY_TOKEN');
        
        return;
      }
      
      const isValidToken = await verifyPlayIntegrityToken(threatData.integrity_token);
      
      if (!isValidToken) {
        console.error('❌ Invalid Play Integrity token:', threatId);
        
        // Delete fraudulent report
        await snap.ref.delete();
        
        // Blacklist device immediately
        await blacklistDevice(threatData.device_id || 'UNKNOWN', {
          reason: 'INVALID_INTEGRITY_TOKEN',
          severity: 'CRITICAL',
          incidentId: threatId,
        });
        
        return;
      }
      
      console.log('✅ Play Integrity token verified:', threatId);
      
      // 🔥 STEP 2: Analyze threat severity
      const severity = threatData.severity;
      
      // 🔥 STEP 3: Update global threat statistics
      await updateGlobalStats(threatData);
      
      // 🔥 STEP 4: Check if HIGH/CRITICAL threat requires bank alert
      if (severity === 'HIGH' || severity === 'CRITICAL') {
        await alertBankPartners(threatData, threatId);
      }
      
      // 🔥 STEP 5: Store in analytics collection for dashboard
      await db.collection('threat_analytics').add({
        threat_id: threatId,
        threat_type: threatData.threat_type,
        severity: severity,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        region: threatData.region || 'UNKNOWN',
        device_type: threatData.device_type || 'UNKNOWN',
        verified: true, // 🔥 Token verified
      });
      
      console.log('✅ Threat processed successfully:', threatId);
      
    } catch (error) {
      console.error('❌ Error processing threat:', error);
      
      // Log error for monitoring
      await db.collection('system_errors').add({
        function: 'processThreatIntel',
        threat_id: threatId,
        error: error.message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * 🔥 NEW: Verify Play Integrity Token
 * Uses Google Cloud reCAPTCHA Enterprise
 */
async function verifyPlayIntegrityToken(token) {
  try {
    // Decode the token
    const request = {
      parent: projectPath,
      assessment: {
        event: {
          token: token,
          siteKey: 'YOUR_RECAPTCHA_SITE_KEY', // 🔥 TODO: Replace with actual site key
        },
      },
    };
    
    const [response] = await recaptchaClient.createAssessment(request);
    
    // Check token validity
    const tokenProperties = response.tokenProperties;
    
    if (!tokenProperties.valid) {
      console.warn('⚠️ Invalid token:', tokenProperties.invalidReason);
      return false;
    }
    
    // Check if app is recognized by Play Store
    const riskAnalysis = response.riskAnalysis;
    const score = riskAnalysis.score || 0;
    
    // Score ranges from 0.0 (very suspicious) to 1.0 (legitimate)
    if (score < 0.5) {
      console.warn('⚠️ Low integrity score:', score);
      return false;
    }
    
    console.log('✅ Token verified with score:', score);
    return true;
    
  } catch (error) {
    console.error('❌ Token verification error:', error);
    return false; // Fail secure
  }
}

/**
 * Update global threat statistics
 */
async function updateGlobalStats(threatData) {
  const statsRef = db.collection('threat_statistics').doc('global');
  
  await db.runTransaction(async (transaction) => {
    const statsDoc = await transaction.get(statsRef);
    
    if (!statsDoc.exists) {
      // Create initial stats
      transaction.set(statsRef, {
        total_threats: 1,
        by_severity: {
          CRITICAL: threatData.severity === 'CRITICAL' ? 1 : 0,
          HIGH: threatData.severity === 'HIGH' ? 1 : 0,
          MEDIUM: threatData.severity === 'MEDIUM' ? 1 : 0,
        },
        by_type: {
          [threatData.threat_type]: 1,
        },
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // Update existing stats
      transaction.update(statsRef, {
        total_threats: admin.firestore.FieldValue.increment(1),
        [`by_severity.${threatData.severity}`]: admin.firestore.FieldValue.increment(1),
        [`by_type.${threatData.threat_type}`]: admin.firestore.FieldValue.increment(1),
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
  
  console.log('📊 Global stats updated');
}

/**
 * 🏦 Alert Bank Partners
 */
async function alertBankPartners(threatData, threatId) {
  console.log('🏦 BANK ALERT TRIGGERED:', {
    threat_id: threatId,
    severity: threatData.severity,
    type: threatData.threat_type,
    timestamp: new Date().toISOString(),
  });
  
  const alertPayload = {
    alert_id: `ALERT_${Date.now()}`,
    threat_id: threatId,
    severity: threatData.severity,
    threat_type: threatData.threat_type,
    region: threatData.region,
    device_os: threatData.device_os,
    indicators: threatData.indicators,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    message: `HIGH SEVERITY THREAT DETECTED: ${threatData.threat_type}`,
  };
  
  await db.collection('bank_alerts').add(alertPayload);
  
  console.log('✅ Bank alert sent:', alertPayload.alert_id);
}

/**
 * 🔥 NEW: Blacklist Device
 */
async function blacklistDevice(deviceId, options = {}) {
  const { reason, severity, incidentId } = options;
  
  await db.collection('blacklisted_devices').doc(deviceId).set({
    deviceId,
    reason: reason || 'SECURITY_INCIDENT',
    severity: severity || 'HIGH',
    incidentId,
    blacklistedAt: admin.firestore.FieldValue.serverTimestamp(),
    type: severity === 'CRITICAL' ? 'PERMANENT' : 'TEMPORARY',
    expiresAt: severity === 'CRITICAL' ? null : new Date(Date.now() + 3600000), // 1 hour
  }, { merge: true });
  
  console.log(`🚫 Device blacklisted: ${deviceId}`);
}

/**
 * 🔥 NEW: Flag Suspicious Activity
 */
async function flagSuspiciousActivity(deviceId, reason) {
  await db.collection('suspicious_activity').add({
    deviceId,
    reason,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  console.log(`⚠️ Suspicious activity flagged: ${deviceId} - ${reason}`);
}

/**
 * 📊 Get Threat Statistics (Callable Function)
 */
exports.getThreatStats = functions
  .region(region)
  .https
  .onCall(async (data, context) => {
    
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    
    try {
      const statsDoc = await db.collection('threat_statistics').doc('global').get();
      
      if (!statsDoc.exists) {
        return {
          total_threats: 0,
          by_severity: {},
          by_type: {},
          message: 'No threats recorded yet',
        };
      }
      
      return statsDoc.data();
      
    } catch (error) {
      console.error('Error getting stats:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

/**
 * 🗺️ Get Threat Heatmap Data
 */
exports.getThreatHeatmap = functions
  .region(region)
  .https
  .onCall(async (data, context) => {
    
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    }
    
    try {
      const { timeRange = '24h' } = data;
      
      let cutoffTime = new Date();
      if (timeRange === '24h') {
        cutoffTime.setHours(cutoffTime.getHours() - 24);
      } else if (timeRange === '7d') {
        cutoffTime.setDate(cutoffTime.getDate() - 7);
      } else if (timeRange === '30d') {
        cutoffTime.setDate(cutoffTime.getDate() - 30);
      }
      
      const threatsSnapshot = await db
        .collection('global_threat_intel')
        .where('timestamp', '>', cutoffTime)
        .get();
      
      const heatmapData = {};
      threatsSnapshot.forEach(doc => {
        const data = doc.data();
        const region = data.region || 'UNKNOWN';
        
        if (!heatmapData[region]) {
          heatmapData[region] = {
            total: 0,
            by_severity: { CRITICAL: 0, HIGH: 0, MEDIUM: 0 },
            by_type: {},
          };
        }
        
        heatmapData[region].total++;
        heatmapData[region].by_severity[data.severity] = 
          (heatmapData[region].by_severity[data.severity] || 0) + 1;
        heatmapData[region].by_type[data.threat_type] = 
          (heatmapData[region].by_type[data.threat_type] || 0) + 1;
      });
      
      return {
        timeRange,
        data: heatmapData,
        total_threats: threatsSnapshot.size,
      };
      
    } catch (error) {
      console.error('Error getting heatmap:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

/**
 * 🧹 Cleanup Old Threat Data (Scheduled)
 */
exports.cleanupOldThreats = functions
  .region(region)
  .pubsub
  .schedule('0 2 * * *')
  .timeZone('Asia/Kuala_Lumpur')
  .onRun(async (context) => {
    
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 90);
    
    const threatsSnapshot = await db
      .collection('global_threat_intel')
      .where('timestamp', '<', cutoffDate)
      .get();
    
    const batch = db.batch();
    threatsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    
    console.log(`🧹 Deleted ${threatsSnapshot.size} old threat records`);
    
    return null;
  });
