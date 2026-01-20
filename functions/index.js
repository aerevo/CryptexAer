/**
 * Z-KINETIC FIREBASE CLOUD FUNCTIONS V3.0
 * Black Box AI Server - Main Entry Point
 * PART 1: Initialization & Core Functions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const AIEngine = require('./blackbox/ai_engine');
const ThreatAnalyzer = require('./blackbox/threat_analyzer');
const AdaptiveLearning = require('./blackbox/adaptive_learning');
const Security = require('./utils/security');

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const aiEngine = new AIEngine();
const threatAnalyzer = new ThreatAnalyzer();
const adaptiveLearning = new AdaptiveLearning(db);
const security = new Security(db);

// Configure region (Singapore - closest to Malaysia)
const region = 'asia-southeast1';

/**
 * 🧠 BLACK BOX AI ANALYSIS
 * Main biometric verification endpoint
 */
exports.analyzeBlackBox = functions
  .region(region)
  .runWith({
    timeoutSeconds: 10,
    memory: '512MB'
  })
  .https
  .onCall(async (data, context) => {
    
    // Authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }
    
    const { deviceId, biometric, sessionId, nonce, timestamp } = data;
    
    // Validate required fields
    if (!deviceId || !biometric || !sessionId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields'
      );
    }
    
    try {
      // 1. Security checks
      const isBlacklisted = await security.isDeviceBlacklisted(deviceId);
      if (isBlacklisted) {
        return {
          allowed: false,
          confidence: 0,
          verdict: 'DEVICE_BLACKLISTED',
          reason: 'Device flagged for suspicious activity'
        };
      }
      
      // 2. Nonce validation (replay attack prevention)
      const isValidNonce = await security.validateNonce(deviceId, nonce, timestamp);
      if (!isValidNonce) {
        await security.flagSuspiciousActivity(deviceId, 'REPLAY_ATTACK_ATTEMPT');
        return {
          allowed: false,
          confidence: 0,
          verdict: 'REPLAY_DETECTED',
          reason: 'Request replay detected'
        };
      }
      
      // 3. Get user baseline from Firestore
      const baseline = await adaptiveLearning.getBaseline(deviceId);
      
      // 4. RUN AI ANALYSIS (BLACK BOX MAGIC!)
      const verdict = await aiEngine.analyze({
        biometric,
        baseline,
        deviceId,
        sessionId
      });
      
      // 5. Update baseline if legitimate
      if (verdict.allowed && verdict.confidence > 0.8) {
        await adaptiveLearning.updateBaseline(deviceId, biometric);
      }
      
      // 6. Log verification (analytics)
      await db.collection('verification_logs').add({
        deviceId,
        sessionId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        verdict: verdict.allowed,
        confidence: verdict.confidence,
        threatLevel: verdict.threatLevel
      });
      
      // 7. Return verdict (client can't see HOW we decided!)
      return {
        allowed: verdict.allowed,
        confidence: verdict.confidence,
        verdict: verdict.verdict,
        threatLevel: verdict.threatLevel,
        reason: verdict.reason || null
      };
      
    } catch (error) {
      console.error('Black Box Analysis Error:', error);
      
      // Log error for monitoring
      await db.collection('system_errors').add({
        function: 'analyzeBlackBox',
        deviceId,
        error: error.message,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      
      throw new functions.https.HttpsError(
        'internal',
        'Analysis failed',
        error.message
      );
    }
  });
/**
 * Z-KINETIC FIREBASE CLOUD FUNCTIONS V3.0
 * PART 2: Incident Reporting & Utility Functions
 */

/**
 * 🚨 INCIDENT REPORTING
 * Security threat intelligence endpoint
 */
exports.reportIncident = functions
  .region(region)
  .runWith({
    timeoutSeconds: 10,
    memory: '256MB'
  })
  .https
  .onCall(async (data, context) => {
    
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }
    
    const { incidentId, deviceId, threatIntel, securityContext } = data;
    
    try {
      // Analyze threat severity
      const analysis = threatAnalyzer.analyze(threatIntel);
      
      // Store incident
      await db.collection('security_incidents').doc(incidentId).set({
        incidentId,
        deviceId,
        threatIntel,
        securityContext,
        analysis,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        severity: analysis.severity
      });
      
      // Check if device should be blacklisted
      const incidentSnapshot = await db
        .collection('security_incidents')
        .where('deviceId', '==', deviceId)
        .where('analysis.severity', 'in', ['CRITICAL', 'HIGH'])
        .get();
      
      const criticalIncidents = incidentSnapshot.size;
      let deviceBlacklisted = false;
      
      if (criticalIncidents >= 3 || analysis.severity === 'CRITICAL') {
        await security.blacklistDevice(deviceId, {
          reason: analysis.severity === 'CRITICAL' ? 'CRITICAL_THREAT' : 'MULTIPLE_INCIDENTS',
          incidentId,
          severity: analysis.severity
        });
        deviceBlacklisted = true;
      }
      
      return {
        success: true,
        incidentId,
        severity: analysis.severity,
        actions: {
          logged: true,
          deviceBlacklisted,
          alertSent: analysis.severity === 'CRITICAL'
        },
        threatAnalysis: {
          type: analysis.type,
          attackVector: analysis.attackVector,
          confidence: analysis.confidence
        }
      };
      
    } catch (error) {
      console.error('Incident Reporting Error:', error);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to process incident',
        error.message
      );
    }
  });

/**
 * 📊 GET USER BASELINE
 * Retrieve user's behavioral baseline
 */
exports.getBaseline = functions
  .region(region)
  .https
  .onCall(async (data, context) => {
    
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Auth required');
    }
    
    const { deviceId } = data;
    
    try {
      const baseline = await adaptiveLearning.getBaseline(deviceId);
      return baseline || { message: 'No baseline found. Building profile...' };
    } catch (error) {
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

/**
 * 🔄 KEEP WARM FUNCTION
 * Prevents cold starts by calling function every 5 minutes
 */
exports.keepWarm = functions
  .region(region)
  .pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('Keep-warm ping executed');
    return null;
  });

/**
 * 🧹 CLEANUP OLD LOGS
 * Delete logs older than 30 days (daily at 2 AM)
 */
exports.cleanupOldLogs = functions
  .region(region)
  .pubsub
  .schedule('0 2 * * *')
  .timeZone('Asia/Kuala_Lumpur')
  .onRun(async (context) => {
    
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 30);
    
    const logsSnapshot = await db
      .collection('verification_logs')
      .where('timestamp', '<', cutoffDate)
      .get();
    
    const batch = db.batch();
    logsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`Deleted ${logsSnapshot.size} old logs`);
    
    return null;
  });
