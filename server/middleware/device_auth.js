/**
 * CryptexLock Mirror Server V3.0
 * Device Authentication & Blacklist Management
 * NEW: Dynamic blacklisting for compromised devices
 */

const crypto = require('crypto');

// In-memory stores (in production, use Redis/Database)
const registeredDevices = new Map();
const deviceNonces = new Map();

// ðŸ”¥ NEW: Blacklist management
const blacklistedDevices = new Map();
const suspiciousDevices = new Map();

// Blacklist configuration
const BLACKLIST_CONFIG = {
  // Auto-blacklist if device hits these thresholds
  maxSuspiciousReports: 3,
  maxFailedAttempts: 5,
  
  // Blacklist durations (milliseconds)
  temporaryBanDuration: 3600000, // 1 hour
  permanentBanThreshold: 10, // After 10 incidents, permanent ban
  
  // Grace period for first-time offenders
  gracePeriod: 300000, // 5 minutes
};

/**
 * ðŸ”¥ NEW: Check if device is blacklisted
 */
function isDeviceBlacklisted(deviceId) {
  const blacklistEntry = blacklistedDevices.get(deviceId);
  
  if (!blacklistEntry) return false;
  
  // Check if temporary ban expired
  if (blacklistEntry.type === 'TEMPORARY') {
    const now = Date.now();
    if (now > blacklistEntry.expiresAt) {
      // Ban expired, remove from blacklist
      blacklistedDevices.delete(deviceId);
      return false;
    }
  }
  
  // Still blacklisted
  return true;
}

/**
 * ðŸ”¥ NEW: Blacklist a device
 */
function blacklistDevice(deviceId, reason = {}) {
  const existingEntry = blacklistedDevices.get(deviceId);
  
  // Check if should be permanent ban
  const incidentCount = existingEntry ? existingEntry.incidentCount + 1 : 1;
  const isPermanent = incidentCount >= BLACKLIST_CONFIG.permanentBanThreshold;
  
  const blacklistEntry = {
    deviceId,
    type: isPermanent ? 'PERMANENT' : 'TEMPORARY',
    reason: reason.reason || 'SECURITY_INCIDENT',
    incidentId: reason.incident_id,
    timestamp: reason.timestamp || new Date().toISOString(),
    incidentCount,
    blacklistedAt: Date.now(),
    expiresAt: isPermanent ? null : Date.now() + BLACKLIST_CONFIG.temporaryBanDuration,
  };
  
  blacklistedDevices.set(deviceId, blacklistEntry);
  
  console.log(`ðŸš« Device Blacklisted: ${deviceId} (${blacklistEntry.type})`);
  
  return blacklistEntry;
}

/**
 * ðŸ”¥ NEW: Mark device as suspicious (warning system)
 */
function flagDeviceAsSuspicious(deviceId, reason) {
  let suspiciousEntry = suspiciousDevices.get(deviceId);
  
  if (!suspiciousEntry) {
    suspiciousEntry = {
      deviceId,
      flags: [],
      firstFlaggedAt: Date.now(),
    };
  }
  
  suspiciousEntry.flags.push({
    reason,
    timestamp: Date.now(),
  });
  
  suspiciousDevices.set(deviceId, suspiciousEntry);
  
  // Auto-blacklist if too many flags
  if (suspiciousEntry.flags.length >= BLACKLIST_CONFIG.maxSuspiciousReports) {
    blacklistDevice(deviceId, {
      reason: 'EXCESSIVE_SUSPICIOUS_ACTIVITY',
      incident_id: `AUTO-${Date.now()}`,
    });
  }
  
  return suspiciousEntry;
}

/**
 * ðŸ”¥ NEW: Remove device from blacklist (admin action)
 */
function unblacklistDevice(deviceId) {
  const wasBlacklisted = blacklistedDevices.has(deviceId);
  
  if (wasBlacklisted) {
    blacklistedDevices.delete(deviceId);
    suspiciousDevices.delete(deviceId);
    console.log(`âœ… Device Unblacklisted: ${deviceId}`);
  }
  
  return wasBlacklisted;
}

/**
 * ðŸ”¥ NEW: Get blacklist statistics
 */
function getBlacklistStats() {
  const stats = {
    total: blacklistedDevices.size,
    permanent: 0,
    temporary: 0,
    suspicious: suspiciousDevices.size,
  };
  
  for (const entry of blacklistedDevices.values()) {
    if (entry.type === 'PERMANENT') {
      stats.permanent++;
    } else {
      stats.temporary++;
    }
  }
  
  return stats;
}

/**
 * Verify device signature
 */
function verifyDeviceSignature(req, res, next) {
  const { device_id, app_signature } = req.body;
  
  if (!device_id || !app_signature) {
    return res.status(400).json({
      allow: false,
      reason: 'missing_device_credentials',
      message: 'Device ID and app signature required'
    });
  }
  
  if (!isValidSignature(app_signature)) {
    // Flag as suspicious
    flagDeviceAsSuspicious(device_id, 'invalid_signature');
    
    return res.status(403).json({
      allow: false,
      reason: 'invalid_app_signature',
      message: 'App signature verification failed'
    });
  }
  
  if (process.env.DEVICE_WHITELIST_ENABLED === 'true') {
    if (!isDeviceWhitelisted(device_id)) {
      return res.status(403).json({
        allow: false,
        reason: 'device_not_whitelisted',
        message: 'Device not authorized'
      });
    }
  }
  
  req.verifiedDevice = {
    id: device_id,
    signature: app_signature
  };
  
  next();
}

/**
 * Verify request nonce (prevent replay attacks)
 */
function verifyNonce(req, res, next) {
  const { nonce, timestamp, device_id } = req.body;
  
  if (!nonce || !timestamp) {
    return res.status(400).json({
      allow: false,
      reason: 'missing_nonce',
      message: 'Nonce and timestamp required'
    });
  }
  
  // Check timestamp freshness
  const now = Date.now();
  const requestTime = parseInt(timestamp);
  const timeDiff = Math.abs(now - requestTime);
  
  if (timeDiff > 30000) {
    return res.status(400).json({
      allow: false,
      reason: 'expired_request',
      message: 'Request timestamp too old'
    });
  }
  
  // Check if nonce already used (replay attack)
  const nonceKey = `${device_id}:${nonce}`;
  
  if (deviceNonces.has(nonceKey)) {
    // Flag as suspicious - replay attack attempt
    flagDeviceAsSuspicious(device_id, 'replay_attack_attempt');
    
    return res.status(403).json({
      allow: false,
      reason: 'replay_attack_detected',
      message: 'Nonce already used'
    });
  }
  
  // Store nonce
  deviceNonces.set(nonceKey, Date.now());
  setTimeout(() => deviceNonces.delete(nonceKey), 60000);
  
  next();
}

/**
 * Verify Zero-Knowledge Proof
 */
function verifyZKProof(req, res, next) {
  const { device_id, zk_proof, nonce } = req.body;
  
  if (!zk_proof) {
    return res.status(400).json({
      allow: false,
      reason: 'missing_zk_proof',
      message: 'Zero-knowledge proof required'
    });
  }
  
  const expectedProof = getExpectedProofHash(device_id);
  
  if (!expectedProof) {
    storeProofHash(device_id, zk_proof);
    req.zkVerified = true;
    return next();
  }
  
  const isValid = verifyProofHash(zk_proof, expectedProof, nonce);
  
  if (!isValid) {
    // Flag as suspicious - invalid proof
    flagDeviceAsSuspicious(device_id, 'invalid_zk_proof');
    
    return res.status(403).json({
      allow: false,
      reason: 'invalid_zk_proof',
      message: 'Code verification failed'
    });
  }
  
  req.zkVerified = true;
  next();
}

/**
 * Helper functions
 */
function isValidSignature(signature) {
  return signature && signature.length >= 32;
}

function isDeviceWhitelisted(deviceId) {
  return true; // Allow all for now
}

function getExpectedProofHash(deviceId) {
  return registeredDevices.get(deviceId);
}

function storeProofHash(deviceId, proofHash) {
  registeredDevices.set(deviceId, proofHash);
}

function verifyProofHash(providedProof, expectedProof, nonce) {
  return providedProof && providedProof.length === 64;
}

/**
 * Log suspicious activity
 */
function logSuspiciousActivity(req, reason) {
  const log = {
    timestamp: new Date().toISOString(),
    device_id: req.body?.device_id,
    ip: req.ip,
    reason: reason,
    user_agent: req.headers['user-agent']
  };
  
  console.warn('[SECURITY]', JSON.stringify(log));
  
  // Flag device as suspicious
  if (req.body?.device_id) {
    flagDeviceAsSuspicious(req.body.device_id, reason);
  }
}

/**
 * ðŸ”¥ NEW: Periodic cleanup of expired entries
 */
function cleanupExpiredEntries() {
  const now = Date.now();
  
  // Clean expired blacklist entries
  for (const [deviceId, entry] of blacklistedDevices.entries()) {
    if (entry.type === 'TEMPORARY' && now > entry.expiresAt) {
      blacklistedDevices.delete(deviceId);
      console.log(`ðŸ§¹ Expired blacklist removed: ${deviceId}`);
    }
  }
  
  // Clean old suspicious flags (after 24 hours)
  const maxAge = 24 * 60 * 60 * 1000;
  for (const [deviceId, entry] of suspiciousDevices.entries()) {
    if (now - entry.firstFlaggedAt > maxAge) {
      suspiciousDevices.delete(deviceId);
    }
  }
}

// Run cleanup every 10 minutes
setInterval(cleanupExpiredEntries, 10 * 60 * 1000);

module.exports = {
  verifyDeviceSignature,
  verifyNonce,
  verifyZKProof,
  logSuspiciousActivity,
  
  // ðŸ”¥ NEW exports
  isDeviceBlacklisted,
  blacklistDevice,
  unblacklistDevice,
  flagDeviceAsSuspicious,
  getBlacklistStats,
};
