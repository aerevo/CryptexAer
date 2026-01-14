/**
 * CryptexLock Mirror Server V3.0
 * Main Express Application
 * NEW: Incident Reporting Endpoint + Threat Intelligence
 */

require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const crypto = require('crypto');
const winston = require('winston');
const path = require('path');

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
  logSuspiciousActivity,
  blacklistDevice,
  isDeviceBlacklisted
} = require('./middleware/device_auth');

// Initialize app
const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Initialize validator
const biometricValidator = new BiometricValidator();

// =========================================================
// WINSTON LOGGER SETUP
// =========================================================

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    // Console output
    new winston.transports.Console({
      format: winston.format.simple()
    }),
    // Incident reports file
    new winston.transports.File({
      filename: path.join(__dirname, 'logs', 'incidents.log'),
      level: 'warn'
    }),
    // All logs file
    new winston.transports.File({
      filename: path.join(__dirname, 'logs', 'combined.log')
    }),
    // Critical threats only
    new winston.transports.File({
      filename: path.join(__dirname, 'logs', 'threats.log'),
      level: 'error'
    })
  ]
});

// =========================================================
// MIDDLEWARE STACK
// =========================================================

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

const corsOptions = {
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['POST', 'GET'],
  allowedHeaders: ['Content-Type', 'X-Client-Version', 'X-Device-ID'],
  credentials: true
};

if (process.env.CORS_ENABLED === 'true') {
  app.use(cors(corsOptions));
}

app.use(express.json({ limit: '50kb' })); // Increased for incident reports

// Request logging
if (process.env.LOG_REQUESTS === 'true') {
  app.use((req, res, next) => {
    logger.info(`${req.method} ${req.path} - ${req.ip}`);
    next();
  });
}

app.use(ipRateLimiter);

// =========================================================
// HEALTH CHECK ENDPOINT
// =========================================================

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '3.0.0'
  });
});

app.get('/', (req, res) => {
  res.status(200).json({
    service: 'CryptexLock Mirror Server',
    version: '3.0.0',
    status: 'operational',
    endpoints: {
      verify: 'POST /api/v1/verify',
      report: 'POST /api/v1/report-incident'
    }
  });
});

// =========================================================
// ðŸš¨ NEW: INCIDENT REPORTING ENDPOINT
// =========================================================

app.post('/api/v1/report-incident',
  // Basic rate limiting (more lenient for reports)
  ipRateLimiter,
  
  async (req, res) => {
    try {
      const report = req.body;
      
      // Validate report structure
      if (!report.incident_id || !report.threat_intel) {
        return res.status(400).json({
          success: false,
          message: 'Invalid incident report structure'
        });
      }
      
      const {
        incident_id,
        timestamp,
        device_fingerprint,
        threat_intel,
        security_context,
        action_taken
      } = report;
      
      // Analyze threat type and severity
      const threatAnalysis = biometricValidator.analyzeThreat(threat_intel);
      
      // Log incident with severity
      const logLevel = threatAnalysis.severity === 'CRITICAL' ? 'error' : 'warn';
      
      logger.log(logLevel, 'Security Incident Reported', {
        incident_id,
        timestamp,
        device: device_fingerprint,
        threat_type: threatAnalysis.type,
        severity: threatAnalysis.severity,
        attack_vector: threatAnalysis.attackVector,
        original_value: threat_intel.original_val,
        manipulated_value: threat_intel.manipulated_val,
        ip: req.ip,
        user_agent: req.headers['user-agent']
      });
      
      // ðŸ”¥ CRITICAL THREAT ACTIONS
      if (threatAnalysis.severity === 'CRITICAL') {
        // Blacklist device immediately
        blacklistDevice(device_fingerprint, {
          reason: threatAnalysis.type,
          incident_id,
          timestamp
        });
        
        // Block IP aggressively (adaptive rate limiting)
        adaptiveRateLimiter.blockIP(req.ip, 3600); // 1 hour block
        
        logger.error('CRITICAL THREAT - Device Blacklisted', {
          device: device_fingerprint,
          ip: req.ip,
          incident_id
        });
      }
      
      // Generate incident receipt
      const receipt = {
        success: true,
        incident_id,
        received_at: new Date().toISOString(),
        severity: threatAnalysis.severity,
        actions_taken: {
          logged: true,
          device_blacklisted: threatAnalysis.severity === 'CRITICAL',
          ip_restricted: threatAnalysis.severity === 'CRITICAL',
          law_enforcement_notified: false // Manual process
        },
        threat_analysis: {
          type: threatAnalysis.type,
          attack_vector: threatAnalysis.attackVector,
          confidence: threatAnalysis.confidence
        }
      };
      
      // Respond to client
      res.status(200).json(receipt);
      
      // ðŸ“§ Optional: Send alert to security team
      if (threatAnalysis.severity === 'CRITICAL') {
        // TODO: Integrate with alerting system (Slack, Email, PagerDuty)
        console.log('ðŸš¨ CRITICAL ALERT: Notify security team!');
      }
      
    } catch (error) {
      logger.error('Incident Report Processing Error', {
        error: error.message,
        stack: error.stack
      });
      
      res.status(500).json({
        success: false,
        message: 'Failed to process incident report'
      });
    }
  }
);

// =========================================================
// VERIFICATION ENDPOINT (UPDATED)
// =========================================================

app.post('/api/v1/verify',
  deviceRateLimiter,
  adaptiveRateLimiter.middleware(),
  
  // ðŸ”¥ NEW: Check device blacklist first
  (req, res, next) => {
    const deviceId = req.body.device_id;
    
    if (isDeviceBlacklisted(deviceId)) {
      logger.warn('Blocked request from blacklisted device', {
        device_id: deviceId,
        ip: req.ip
      });
      
      return res.status(403).json({
        allow: false,
        reason: 'device_blacklisted',
        message: 'Device has been flagged for suspicious activity'
      });
    }
    
    next();
  },
  
  verifyDeviceSignature,
  verifyNonce,
  
  async (req, res) => {
    try {
      const payload = req.body;
      
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
        adaptiveRateLimiter.recordFailure(payload.device_id);
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
        exp: Date.now() + 30000,
        nonce: crypto.randomUUID()
      };
      
      const token = signDecision(decision);
      adaptiveRateLimiter.recordSuccess(payload.device_id);
      
      res.status(200).json({
        allow: true,
        token: token,
        expires_in: 30,
        confidence: validation.confidence
      });
      
    } catch (error) {
      logger.error('Verification Error', { error: error.message });
      
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

function signDecision(decision) {
  const secret = process.env.HMAC_SECRET || 'default_secret_change_me';
  const payload = JSON.stringify(decision);
  
  return crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
}

// =========================================================
// ERROR HANDLING
// =========================================================

app.use((req, res) => {
  res.status(404).json({
    error: 'endpoint_not_found',
    message: 'The requested endpoint does not exist'
  });
});

app.use((err, req, res, next) => {
  logger.error('Fatal Error', {
    error: err.message,
    stack: err.stack
  });
  
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
  console.log('='.repeat(60));
  console.log('ðŸ›¡ï¸  CryptexLock Mirror Server V3.0');
  console.log('='.repeat(60));
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Server: http://${HOST}:${PORT}`);
  console.log(`Health: http://${HOST}:${PORT}/health`);
  console.log('');
  console.log('ðŸ“¡ Endpoints:');
  console.log('   POST /api/v1/verify          - Biometric validation');
  console.log('   POST /api/v1/report-incident - Threat intelligence');
  console.log('');
  console.log('ðŸ“ Logging:');
  console.log('   incidents.log - Security incidents');
  console.log('   threats.log   - Critical threats only');
  console.log('   combined.log  - All activity');
  console.log('='.repeat(60));
  console.log('âœ… Server ready and listening...');
  console.log('');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received. Shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received. Shutting down gracefully...');
  process.exit(0);
});

module.exports = app;
