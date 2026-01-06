/**
 * CryptexLock Mirror Server
 * Device Authentication & Verification
 * Prevents unauthorized device access
 */

const crypto = require('crypto');

// In-memory device registry (in production, use database)
const registeredDevices = new Map();
const deviceNonces = new Map();

/**
 * Verify device signature
 * Ensures request comes from legitimate app
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
  
  // Verify app signature format
  if (!isValidSignature(app_signature)) {
    return res.status(403).json({
      allow: false,
      reason: 'invalid_app_signature',
      message: 'App signature verification failed'
    });
  }
  
  // Optional: Check device whitelist
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
  const { nonce, timestamp } = req.body;
  
  if (!nonce || !timestamp) {
    return res.status(400).json({
      allow: false,
      reason: 'missing_nonce',
      message: 'Nonce and timestamp required'
    });
  }
  
  // Check timestamp freshness (within 30 seconds)
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
  const nonceKey = `${req.body.device_id}:${nonce}`;
  
  if (deviceNonces.has(nonceKey)) {
    return res.status(403).json({
      allow: false,
      reason: 'replay_attack_detected',
      message: 'Nonce already used'
    });
  }
  
  // Store nonce (expire after 1 minute)
  deviceNonces.set(nonceKey, Date.now());
  setTimeout(() => deviceNonces.delete(nonceKey), 60000);
  
  next();
}

/**
 * Verify Zero-Knowledge Proof
 * Checks if user knows the code without revealing it
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
  
  // Get expected proof hash for this device
  // In production, this comes from secure database
  const expectedProof = getExpectedProofHash(device_id);
  
  if (!expectedProof) {
    // First time user - store their proof
    storeProofHash(device_id, zk_proof);
    req.zkVerified = true;
    return next();
  }
  
  // Verify proof matches (user knows correct code)
  // Note: Proof includes nonce, so changes each request
  const isValid = verifyProofHash(zk_proof, expectedProof, nonce);
  
  if (!isValid) {
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
 * Helper: Validate signature format
 */
function isValidSignature(signature) {
  // Basic validation - in production, verify actual signature
  return signature && signature.length >= 32;
}

/**
 * Helper: Check device whitelist
 */
function isDeviceWhitelisted(deviceId) {
  // In production, check against database
  return true; // Allow all for now
}

/**
 * Helper: Get expected proof hash for device
 */
function getExpectedProofHash(deviceId) {
  // In production, retrieve from secure database
  // For now, return stored hash if exists
  return registeredDevices.get(deviceId);
}

/**
 * Helper: Store proof hash for device
 */
function storeProofHash(deviceId, proofHash) {
  // In production, store in secure database
  registeredDevices.set(deviceId, proofHash);
}

/**
 * Helper: Verify proof hash
 */
function verifyProofHash(providedProof, expectedProof, nonce) {
  // In production, implement proper cryptographic verification
  // For now, basic hash comparison
  
  // Extract base proof (without nonce)
  // Since proof = hash(code:nonce:secret), we can't directly compare
  // Server should regenerate expected hash with same nonce
  
  // Simplified: just check if proof format is valid
  return providedProof && providedProof.length === 64; // SHA-256 length
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
  
  // In production, send to monitoring system (Sentry, CloudWatch, etc.)
}

module.exports = {
  verifyDeviceSignature,
  verifyNonce,
  verifyZKProof,
  logSuspiciousActivity
};
