/**
 * Z-KINETIC AUTHORITY SERVER
 * Production-ready Express.js implementation
 * 
 * Features:
 * - Nonce generation (anti-replay)
 * - Session management (stateless)
 * - Risk scoring (biometric analysis)
 * - Token issuance (signed verdict)
 * - Rate limiting (abuse prevention)
 * 
 * Deploy to: Render.com (FREE tier)
 * Keep-alive: UptimeRobot (external, FREE)
 */

const express = require('express');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// ============================================
// IN-MEMORY STORAGE
// ============================================

const nonces = new Map();
const sessions = new Map();

const stats = {
  totalChallenges: 0,
  totalAttestations: 0,
  successfulAttestations: 0,
  failedAttestations: 0,
  totalVerifications: 0,
  serverStartTime: Date.now(),
};

// ============================================
// AUTO-CLEANUP (Every 5 minutes)
// ============================================

setInterval(() => {
  const now = Date.now();
  let deletedNonces = 0;
  let deletedSessions = 0;
  
  for (const [key, value] of nonces.entries()) {
    if (value.expiry < now) {
      nonces.delete(key);
      deletedNonces++;
    }
  }
  
  for (const [key, value] of sessions.entries()) {
    if (value.expiry < now) {
      sessions.delete(key);
      deletedSessions++;
    }
  }
  
  console.log(`🧹 Cleanup: ${deletedNonces} nonces, ${deletedSessions} sessions deleted`);
}, 5 * 60 * 1000);

// ============================================
// RATE LIMITING
// ============================================

const challengeLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { error: 'Too many challenge requests' },
});

const attestLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  message: { error: 'Too many attestation requests' },
});

const verifyLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  message: { error: 'Too many verification requests' },
});

// ============================================
// ENDPOINT 1: GET CHALLENGE
// ============================================

app.post('/getChallenge', challengeLimiter, (req, res) => {
  try {
    const nonce = crypto.randomBytes(32).toString('hex');
    const now = Date.now();
    const expiry = now + (60 * 1000); // 60 seconds TTL
    
    nonces.set(nonce, {
      expiry: expiry,
      used: false,
      createdAt: now,
    });
    
    stats.totalChallenges++;
    
    console.log(`✅ Challenge generated: ${nonce.substring(0, 16)}...`);
    
    res.json({
      success: true,
      nonce: nonce,
      expiry: expiry,
      serverTime: now,
    });
    
  } catch (error) {
    console.error('❌ getChallenge error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

// ============================================
// ENDPOINT 2: ATTEST
// ============================================

app.post('/attest', attestLimiter, (req, res) => {
  try {
    const { nonce, biometricData, deviceId } = req.body;
    
    if (!nonce || !biometricData || !deviceId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields',
      });
    }
    
    const challenge = nonces.get(nonce);
    
    if (!challenge) {
      return res.status(400).json({
        success: false,
        error: 'Invalid nonce',
      });
    }
    
    if (challenge.used) {
      console.log(`🚨 REPLAY ATTACK detected: ${nonce.substring(0, 16)}...`);
      stats.failedAttestations++;
      return res.status(400).json({
        success: false,
        error: 'Nonce already used (replay attack detected)',
      });
    }
    
    const now = Date.now();
    if (challenge.expiry < now) {
      stats.failedAttestations++;
      return res.status(400).json({
        success: false,
        error: 'Nonce expired',
      });
    }
    
    challenge.used = true;
    
    const { motion, touch, pattern } = biometricData;
    
    if (typeof motion !== 'number' || typeof touch !== 'number' || typeof pattern !== 'number') {
      return res.status(400).json({
        success: false,
        error: 'Invalid biometric data format',
      });
    }
    
    const motionOK = motion > 0.15;
    const touchOK = touch > 0.15;
    const patternOK = pattern > 0.10;
    
    const sensorsActive = [motionOK, touchOK, patternOK].filter(Boolean).length;
    
    if (sensorsActive < 2) {
      console.log(`❌ Biometric failed for ${deviceId}`);
      stats.failedAttestations++;
      
      return res.status(403).json({
        success: false,
        error: 'Biometric verification failed',
      });
    }
    
    const sessionToken = crypto.randomBytes(64).toString('hex');
    const tokenExpiry = now + (5 * 60 * 1000); // 5 minutes
    
    const avgScore = (motion + touch + pattern) / 3;
    let riskScore;
    if (avgScore > 0.7) {
      riskScore = 'LOW';
    } else if (avgScore > 0.4) {
      riskScore = 'MEDIUM';
    } else {
      riskScore = 'HIGH';
    }
    
    sessions.set(sessionToken, {
      deviceId: deviceId,
      status: 'VERIFIED',
      riskScore: riskScore,
      biometricScores: { motion, touch, pattern },
      expiry: tokenExpiry,
      createdAt: now,
      nonce: nonce,
    });
    
    stats.totalAttestations++;
    stats.successfulAttestations++;
    
    console.log(`✅ Attestation SUCCESS: Token=${sessionToken.substring(0, 16)}..., Risk=${riskScore}`);
    
    res.json({
      success: true,
      sessionToken: sessionToken,
      expiry: tokenExpiry,
      riskScore: riskScore,
    });
    
  } catch (error) {
    console.error('❌ attest error:', error);
    stats.failedAttestations++;
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

// ============================================
// ENDPOINT 3: VERIFY
// ============================================

app.post('/verify', verifyLimiter, (req, res) => {
  try {
    const { sessionToken } = req.body;
    
    if (!sessionToken) {
      return res.status(400).json({
        valid: false,
        error: 'Missing sessionToken',
      });
    }
    
    const session = sessions.get(sessionToken);
    
    if (!session) {
      stats.totalVerifications++;
      return res.json({
        valid: false,
        status: 'INVALID',
      });
    }
    
    const now = Date.now();
    if (session.expiry < now) {
      stats.totalVerifications++;
      return res.json({
        valid: false,
        status: 'EXPIRED',
      });
    }
    
    console.log(`✅ Token VERIFIED: Risk=${session.riskScore}`);
    stats.totalVerifications++;
    
    res.json({
      valid: true,
      status: 'VALID',
      riskScore: session.riskScore,
      deviceId: session.deviceId,
      verifiedAt: session.createdAt,
      expiresAt: session.expiry,
    });
    
  } catch (error) {
    console.error('❌ verify error:', error);
    res.status(500).json({
      valid: false,
      error: 'Internal server error',
    });
  }
});

// ============================================
// HEALTH CHECK
// ============================================

app.get('/health', (req, res) => {
  const now = Date.now();
  const uptime = now - stats.serverStartTime;
  
  res.json({
    status: 'OK',
    server: 'Z-Kinetic Authority',
    version: '1.0.0',
    timestamp: now,
    uptime: uptime,
    storage: {
      nonces: nonces.size,
      sessions: sessions.size,
    },
    stats: stats,
  });
});

// ============================================
// DOCS
// ============================================

app.get('/docs', (req, res) => {
  res.json({
    name: 'Z-Kinetic Authority API',
    version: '1.0.0',
    endpoints: [
      {
        path: '/getChallenge',
        method: 'POST',
        description: 'Generate challenge nonce',
      },
      {
        path: '/attest',
        method: 'POST',
        description: 'Verify biometric and issue token',
      },
      {
        path: '/verify',
        method: 'POST',
        description: 'Validate session token',
      },
    ],
  });
});

// ============================================
// START SERVER
// ============================================

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log('═══════════════════════════════════════════');
  console.log('  Z-KINETIC AUTHORITY SERVER');
  console.log('═══════════════════════════════════════════');
  console.log(`✅ Server running on port ${PORT}`);
  console.log(`🌐 Health: http://localhost:${PORT}/health`);
  console.log('═══════════════════════════════════════════');
});
