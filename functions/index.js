/**
 * Z-KINETIC FIREBASE CLOUD FUNCTIONS V3.1 (TIMEOUT PROTECTED)
 * Status: PRODUCTION READY ✅
 * Fixes:
 * - ✅ AI analysis timeout wrapper (8 seconds max)
 * - ✅ Graceful degradation on timeout
 * - ✅ Error logging for monitoring
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

// ✅ FIX: Timeout wrapper utility
const withTimeout = (promise, timeoutMs, timeoutValue) => {
  return Promise.race([
    promise,
    new Promise((_, reject) => 
      setTimeout(() => reject(new Error('OPERATION_TIMEOUT')), timeoutMs)
    )
  ]).catch(error => {
    if (error.message === 'OPERATION_TIMEOUT') {
      console.warn(`⏱️ Operation timed out after ${timeoutMs}ms`);
      return timeoutValue;
    }
    throw error;
  });
};

/**
 * 🧠 BLACK BOX AI ANALYSIS (✅ TIMEOUT PROTECTED)
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

      // ✅ CRITICAL FIX: Wrap AI analysis with timeout
      const verdict = await withTimeout(
        aiEngine.analyze({
          biometric,
          baseline,
          deviceId,
          sessionId
        }),
        8000, // 8 seconds max (leave 2s buffer for function cleanup)
        {
          allowed: false,
          confidence: 0,
          verdict: 'AI_PROCESSING_TIMEOUT',
          threatLevel: 'SUSPICIOUS',
          reason: 'Analysis took too long - possible attack or system overload'
        }
      );

      // Check if we got a timeout response
      if (verdict.verdict === 'AI_PROCESSING_TIMEOUT') {
        // Log timeout for monitoring
        await db.collection('system_errors').add({
          function: 'analyzeBlackBox',
          error: 'AI_TIMEOUT',
          deviceId,
          sessionId,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        // Flag device as suspicious (might be attack)
        await security.flagSuspiciousActivity(deviceId, 'AI_TIMEOUT_SUSPICIOUS');
        
        return verdict;
      }

      // 5. Update baseline if legitimate
      if (verdict.allowed && verdict.confidence > 0.8) {
        // ✅ FIX: Also wrap baseline update with timeout
        await withTimeout(
          adaptiveLearning.updateBaseline(deviceId, biometric),
          2000, // 2 seconds max
          null // Don't care if this fails
        ).catch(error => {
          console.warn('⚠️ Baseline update failed:', error.message);
          // Don't block user if baseline update fails
        });
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

      // 7. Return verdict
      return {
        allowed: verdict.allowed,
        confidence: verdict.confidence,
        verdict: verdict.verdict,
        threatLevel: verdict.threatLevel,
        reason: verdict.reason || null
      };

    } catch (error) {
      console.error('❌ Black Box Analysis Error:', error);

      // Log error for monitoring
      await db.collection('system_errors').add({
        function: 'analyzeBlackBox',
        deviceId,
        error: error.message,
        stack: error.stack,
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
      console.error('❌ Incident Reporting Error:', error);
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
    console.log('⏰ Keep-warm ping executed');
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
    console.log(`🧹 Deleted ${logsSnapshot.size} old logs`);

    return null;
  });
