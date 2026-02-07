/**
 * Z-KINETIC SERVER - MINIMUM VIABLE PRODUCTION
 * 
 * 3 Jantung Utama:
 * 1. getChallenge - Generate nonce (anti-replay)
 * 2. attest - Verify biometric & issue session token
 * 3. verify - Bank/Partner validation endpoint
 * 
 * Firebase Functions v2
 * Node.js 18
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const crypto = require("crypto");

// Initialize Firebase Admin
admin.initializeApp();

// Firestore reference
const db = admin.firestore();

// ============================================
// ENDPOINT 1: GET CHALLENGE (Generate Nonce)
// ============================================
exports.getChallenge = onCall(
  {
    region: "asia-southeast1",
    timeoutSeconds: 10,
    memory: "256MiB",
  },
  async (request) => {
    try {
      // Generate cryptographically secure nonce
      const nonce = crypto.randomBytes(32).toString("hex");
      const now = Date.now();
      const expiry = now + 60000; // 60 seconds TTL

      // Store nonce in Firestore (temporary)
      await db.collection("challenges").doc(nonce).set({
        created: admin.firestore.FieldValue.serverTimestamp(),
        expiry: expiry,
        used: false,
        ip: request.rawRequest.ip || "unknown",
      });

      console.log(`✅ Nonce generated: ${nonce.substring(0, 16)}...`);

      return {
        success: true,
        nonce: nonce,
        expiry: expiry,
        message: "Challenge generated successfully",
      };
    } catch (error) {
      console.error("❌ getChallenge error:", error);
      throw new HttpsError("internal", "Failed to generate challenge");
    }
  }
);

// ============================================
// ENDPOINT 2: ATTEST (Verify & Issue Token)
// ============================================
exports.attest = onCall(
  {
    region: "asia-southeast1",
    timeoutSeconds: 30,
    memory: "512MiB",
  },
  async (request) => {
    try {
      const {nonce, biometricData, deviceId} = request.data;

      // Validation: Required fields
      if (!nonce || !biometricData || !deviceId) {
        throw new HttpsError(
          "invalid-argument",
          "Missing required fields: nonce, biometricData, deviceId"
        );
      }

      // ─────────────────────────────────────────
      // STEP 1: Verify Nonce (Anti-Replay)
      // ─────────────────────────────────────────
      const challengeRef = db.collection("challenges").doc(nonce);
      const challengeDoc = await challengeRef.get();

      if (!challengeDoc.exists) {
        throw new HttpsError("not-found", "Invalid nonce");
      }

      const challenge = challengeDoc.data();

      // Check if already used
      if (challenge.used) {
        throw new HttpsError("already-exists", "Nonce already used (replay attack detected)");
      }

      // Check if expired
      if (challenge.expiry < Date.now()) {
        throw new HttpsError("deadline-exceeded", "Nonce expired");
      }

      // Mark nonce as used (prevent replay)
      await challengeRef.update({used: true});

      // ─────────────────────────────────────────
      // STEP 2: Verify Biometric Data
      // ─────────────────────────────────────────
      const {motion, touch, pattern} = biometricData;

      // Simple threshold check (production-grade logic)
      const motionOK = motion > 0.15;
      const touchOK = touch > 0.15;
      const patternOK = pattern > 0.10;

      const sensorsActive = [motionOK, touchOK, patternOK].filter(Boolean).length;

      // Require at least 2 sensors passing
      if (sensorsActive < 2) {
        console.log(`❌ Biometric failed for device ${deviceId}: motion=${motion}, touch=${touch}, pattern=${pattern}`);

        // Log failed attempt (for analytics, not blocking)
        await db.collection("failed_attestations").add({
          deviceId: deviceId,
          reason: "insufficient_biometric_signals",
          scores: {motion, touch, pattern},
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        throw new HttpsError(
          "permission-denied",
          "Biometric verification failed: insufficient human signals"
        );
      }

      // ─────────────────────────────────────────
      // STEP 3: Generate Session Token
      // ─────────────────────────────────────────
      const sessionToken = crypto.randomBytes(64).toString("hex");
      const tokenExpiry = Date.now() + 300000; // 5 minutes validity

      // Calculate risk score (0-100)
      const avgScore = (motion + touch + pattern) / 3;
      let riskScore;
      if (avgScore > 0.7) {
        riskScore = "LOW";
      } else if (avgScore > 0.4) {
        riskScore = "MEDIUM";
      } else {
        riskScore = "HIGH";
      }

      // Store session in Firestore
      await db.collection("sessions").doc(sessionToken).set({
        deviceId: deviceId,
        status: "VERIFIED",
        riskScore: riskScore,
        biometricScores: {motion, touch, pattern},
        created: admin.firestore.FieldValue.serverTimestamp(),
        expiry: tokenExpiry,
        nonce: nonce, // Audit trail
      });

      console.log(`✅ Attestation successful for device ${deviceId}: Token=${sessionToken.substring(0, 16)}..., Risk=${riskScore}`);

      return {
        success: true,
        sessionToken: sessionToken,
        expiry: tokenExpiry,
        riskScore: riskScore,
        message: "Biometric verification passed",
      };
    } catch (error) {
      // Re-throw HttpsError as-is
      if (error instanceof HttpsError) {
        throw error;
      }

      // Log unexpected errors
      console.error("❌ attest error:", error);
      throw new HttpsError("internal", "Attestation failed");
    }
  }
);

// ============================================
// ENDPOINT 3: VERIFY (Bank/Partner Check)
// ============================================
exports.verify = onCall(
  {
    region: "asia-southeast1",
    timeoutSeconds: 10,
    memory: "256MiB",
  },
  async (request) => {
    try {
      const {sessionToken} = request.data;

      // Validation
      if (!sessionToken) {
        throw new HttpsError("invalid-argument", "Missing sessionToken");
      }

      // Retrieve session from Firestore
      const sessionRef = db.collection("sessions").doc(sessionToken);
      const sessionDoc = await sessionRef.get();

      if (!sessionDoc.exists) {
        console.log(`❌ Invalid token verification attempt: ${sessionToken.substring(0, 16)}...`);
        return {
          valid: false,
          status: "INVALID",
          message: "Token not found",
        };
      }

      const session = sessionDoc.data();

      // Check if expired
      if (session.expiry < Date.now()) {
        console.log(`❌ Expired token verification attempt: ${sessionToken.substring(0, 16)}...`);
        return {
          valid: false,
          status: "EXPIRED",
          message: "Token expired",
        };
      }

      // Token is valid
      console.log(`✅ Token verified: ${sessionToken.substring(0, 16)}..., Risk=${session.riskScore}`);

      return {
        valid: true,
        status: "VALID",
        riskScore: session.riskScore,
        deviceId: session.deviceId,
        verifiedAt: session.created,
        expiresAt: session.expiry,
        message: "Token is valid",
      };
    } catch (error) {
      // Re-throw HttpsError as-is
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("❌ verify error:", error);
      throw new HttpsError("internal", "Verification failed");
    }
  }
);

// ============================================
// SCHEDULED CLEANUP (Every 5 minutes)
// ============================================
exports.cleanupExpired = onSchedule(
  {
    schedule: "*/5 * * * *", // Every 5 minutes
    region: "asia-southeast1",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (event) => {
    const now = Date.now();
    let deletedChallenges = 0;
    let deletedSessions = 0;

    try {
      // Cleanup expired challenges
      const expiredChallenges = await db
        .collection("challenges")
        .where("expiry", "<", now)
        .limit(500)
        .get();

      const challengeBatch = db.batch();
      expiredChallenges.forEach((doc) => {
        challengeBatch.delete(doc.ref);
        deletedChallenges++;
      });
      await challengeBatch.commit();

      // Cleanup expired sessions
      const expiredSessions = await db
        .collection("sessions")
        .where("expiry", "<", now)
        .limit(500)
        .get();

      const sessionBatch = db.batch();
      expiredSessions.forEach((doc) => {
        sessionBatch.delete(doc.ref);
        deletedSessions++;
      });
      await sessionBatch.commit();

      console.log(`🧹 Cleanup complete: ${deletedChallenges} challenges, ${deletedSessions} sessions deleted`);
    } catch (error) {
      console.error("❌ Cleanup error:", error);
    }
  }
);

// ============================================
// HEALTH CHECK (For Monitoring)
// ============================================
exports.health = onCall(
  {
    region: "asia-southeast1",
    timeoutSeconds: 5,
    memory: "128MiB",
  },
  async (request) => {
    return {
      status: "OK",
      server: "Z-Kinetic Attestation Authority",
      version: "1.0.0",
      region: "asia-southeast1",
      timestamp: Date.now(),
    };
  }
);
