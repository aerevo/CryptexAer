/**
 * CryptexLock Mirror Server
 * Main Express Application
 * Zero-Knowledge Proof Validation System
 */

require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const crypto = require('crypto');

// Import services and middleware
const BiometricValidator = require('./services/biometric_validator');
const {
  deviceRateLimiter,
  ipRateLimiter,
  adaptiveRateLimiter
} = require('./middleware/rate_limiter');
const {
  verifyDeviceSignature,
  verifyNonce,
  verifyZKProof,
  logSuspiciousActivity
} = require('./middleware/device_auth');

// Initialize app
const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Initialize validator
const biometricValidator = new BiometricValidator();

// =========================================================
// MIDDLEWARE STACK
// =========================================================

// Security headers
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// CORS
const corsOptions = {
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['POST', 'GET'],
  allowedHeaders: ['Content-Type', 'X-Client-Version', 'X-Device-ID'],
  credentials: true
};

if (process.env.CORS_ENABLED === 'true') {
  app.use(cors(corsOptions));
}

// Body parser
app.use(express.json({ limit: '10kb' }));

// Request logging
if (process.env.LOG_REQUESTS === 'true') {
  app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
  });
}

// IP rate limiting (global)
app.use(ipRateLimiter);

// =========================================================
// HEALTH CHECK ENDPOINT
// =========================================================

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '2.0.4'
  });
});

app.get('/', (req, res) => {
  res.status(200).json({
    service: 'CryptexLock Mirror Server',
    version: '2.0.4',
    status: 'operational'
  });
});

// =========================================================
// MAIN VERIFICATION ENDPOINT
// =========================================================

app.post('/api/v1/verify',
  // Middleware chain
  deviceRateLimiter,           // Rate limit per device
  adaptiveRateLimiter.middleware(), // Adaptive limiting
  verifyDeviceSignature,       // Verify device identity
  verifyNonce,                 // Prevent replay attacks
  // Main handler
  async (req, res) => {
    try {
      const payload = req.body;
      
      // Validate request structure
      if (!payload.biometric || !payload.device_id) {
        return res.status(400).json({
          allow: false,
          reason: 'invalid_payload',
          message: 'Missing required fields'
        });
      }
      
      // Biometric validation
      const validation = biometricValidator.validate(payload);
      
      if (!validation.allowed) {
        // Record failure for adaptive rate limiting
        adaptiveRateLimiter.recordFailure(payload.device_id);
        
        // Log suspicious activity
        logSuspiciousActivity(req, validation.reason);
        
        return res.status(200).json({
          allow: false,
          reason: validation.reason,
          confidence: validation.confidence
        });
      }
      
      // Success - generate signed token
      const decision = {
        allow: true,
        device_id: payload.device_id,
        exp: Date.now() + 30000, // 30 second expiry
        nonce: crypto.randomUUID()
      };
      
      const token = signDecision(decision);
      
      // Record success
      adaptiveRateLimiter.recordSuccess(payload.device_id);
      
      // Success response
      res.status(200).json({
        allow: true,
        token: token,
        expires_in: 30,
        confidence: validation.confidence
      });
      
    } catch (error) {
      console.error('[ERROR]', error);
      
      res.status(500).json({
        allow: false,
        reason: 'server_error',
        message: 'Internal server error'
      });
    }
  }
);

// =========================================================
// HELPER FUNCTIONS
// =========================================================

/**
 * Sign decision with HMAC
 * Prevents token tampering
 */
function signDecision(decision) {
  const secret = process.env.HMAC_SECRET || 'default_secret_change_me';
  const payload = JSON.stringify(decision);
  
  return crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
}

/**
 * Verify token signature (for reference)
 */
function verifyToken(token, decision) {
  const expectedToken = signDecision(decision);
  return crypto.timingSafeEqual(
    Buffer.from(token),
    Buffer.from(expectedToken)
  );
}

// =========================================================
// ERROR HANDLING
// =========================================================

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'endpoint_not_found',
    message: 'The requested endpoint does not exist'
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('[FATAL]', err);
  
  res.status(500).json({
    allow: false,
    reason: 'server_error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
  });
});

// =========================================================
// START SERVER
// =========================================================

app.listen(PORT, HOST, () => {
  console.log('='.repeat(50));
  console.log('🔒 CryptexLock Mirror Server');
  console.log('='.repeat(50));
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Server: http://${HOST}:${PORT}`);
  console.log(`Health: http://${HOST}:${PORT}/health`);
  console.log(`Endpoint: POST /api/v1/verify`);
  console.log('='.repeat(50));
  console.log('✅ Server ready and listening...');
  console.log('');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received. Shutting down gracefully...');
  process.exit(0);
});

module.exports = app;
