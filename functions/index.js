/**
 * FILE: functions/index.js
 * Z-KINETIC CLOUD FUNCTIONS (EDGE COMPUTING MODEL)
 * PURPOSE: Process threat intelligence reports (NO RAW BIOMETRICS)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const region = 'asia-southeast1';

/**
 * 🚨 NEW: Threat Intelligence Processor
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
    });
    
    try {
      // 1. Analyze threat severity
      const severity = threatData.severity;
      
      // 2. Update global threat statistics
      await updateGlobalStats(threatData);
      
      // 3. Check if HIGH/CRITICAL threat requires bank alert
      if (severity === 'HIGH' || severity === 'CRITICAL') {
        await alertBankPartners(threatData, threatId);
      }
      
      // 4. Store in analytics collection for dashboard
      await db.collection('threat_analytics').add({
        threat_id: threatId,
        threat_type: threatData.threat_type,
        severity: severity,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        region: threatData.region || 'UNKNOWN',
        device_type: threatData.device_type || 'UNKNOWN',
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
      const stats = statsDoc.data();
      
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
 * 🏦 Alert Bank Partners (Simulate API Call)
 * In production: Call real bank partner API
 */
async function alertBankPartners(threatData, threatId) {
  console.log('🏦 BANK ALERT TRIGGERED:', {
    threat_id: threatId,
    severity: threatData.severity,
    type: threatData.threat_type,
    timestamp: new Date().toISOString(),
  });
  
  // Simulate API call to bank partner
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
  
  // Store alert for bank partner dashboard
  await db.collection('bank_alerts').add(alertPayload);
  
  // In production, send HTTP request to bank API:
  /*
  const axios = require('axios');
  await axios.post('https://bank-partner-api.com/threats', alertPayload, {
    headers: {
      'Authorization': 'Bearer YOUR_API_KEY',
      'Content-Type': 'application/json',
    },
  });
  */
  
  console.log('✅ Bank alert sent:', alertPayload.alert_id);
}

/**
 * 📊 Get Threat Statistics (Callable Function)
 * For dashboard/analytics
 */
exports.getThreatStats = functions
  .region(region)
  .https
  .onCall(async (data, context) => {
    
    // Authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }
    
    try {
      // Get global stats
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
 * Returns threat distribution by region
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
      
      // Calculate cutoff time
      let cutoffTime = new Date();
      if (timeRange === '24h') {
        cutoffTime.setHours(cutoffTime.getHours() - 24);
      } else if (timeRange === '7d') {
        cutoffTime.setDate(cutoffTime.getDate() - 7);
      } else if (timeRange === '30d') {
        cutoffTime.setDate(cutoffTime.getDate() - 30);
      }
      
      // Query recent threats
      const threatsSnapshot = await db
        .collection('global_threat_intel')
        .where('timestamp', '>', cutoffTime)
        .get();
      
      // Group by region
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
 * Runs daily at 2 AM (Malaysia time)
 */
exports.cleanupOldThreats = functions
  .region(region)
  .pubsub
  .schedule('0 2 * * *')
  .timeZone('Asia/Kuala_Lumpur')
  .onRun(async (context) => {
    
    // Delete threats older than 90 days
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

/**
 * 🔥 Keep Functions Warm
 * Prevents cold starts
 */
exports.keepWarm = functions
  .region(region)
  .pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('⏰ Keep-warm ping executed');
    return null;
  });
