/**
 * CryptexLock Mirror Server V3.0
 * Rate Limiting with Adaptive Blocking
 * NEW: IP blocking based on incident reports
 */

const rateLimit = require('express-rate-limit');
const Redis = require('redis');

// Redis client (optional)
let redisClient = null;

if (process.env.REDIS_ENABLED === 'true') {
  redisClient = Redis.createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379'
  });
  
  redisClient.connect().catch(console.error);
}

/**
 * Device-based rate limiter
 */
const deviceRateLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 5,
  
  keyGenerator: (req) => {
    return req.body?.device_id || req.ip;
  },
  
  store: redisClient ? createRedisStore() : undefined,
  
  handler: (req, res) => {
    res.status(429).json({
      allow: false,
      reason: 'rate_limit_exceeded',
      message: 'Too many attempts. Please try again later.',
      retry_after: req.rateLimit.resetTime
    });
  },
  
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * IP-based rate limiter
 */
const ipRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50,
  
  handler: (req, res) => {
    res.status(429).json({
      allow: false,
      reason: 'ip_rate_limit_exceeded',
      message: 'Too many requests from this IP address.'
    });
  }
});

/**
 * Create Redis store
 */
function createRedisStore() {
  const RedisStore = require('rate-limit-redis');
  
  return new RedisStore({
    client: redisClient,
    prefix: 'cryptex_rl:',
    sendCommand: (...args) => redisClient.sendCommand(args),
  });
}

/**
 * ðŸ”¥ UPGRADED: Adaptive Rate Limiter
 * Now integrates with incident reporting
 */
class AdaptiveRateLimiter {
  constructor() {
    this.failureCount = new Map();
    this.blockedIPs = new Map();
    this.blockedDevices = new Map();
    this.baseLimit = 5;
    
    // Cleanup old entries every 15 minutes
    setInterval(() => this.cleanup(), 15 * 60 * 1000);
  }
  
  middleware() {
    return (req, res, next) => {
      const deviceId = req.body?.device_id;
      const ip = req.ip;
      
      // ðŸ”¥ NEW: Check if IP is blocked
      if (this.isIPBlocked(ip)) {
        const blockInfo = this.blockedIPs.get(ip);
        const remainingTime = Math.ceil((blockInfo.expiresAt - Date.now()) / 1000);
        
        return res.status(403).json({
          allow: false,
          reason: 'ip_blocked',
          message: `IP blocked due to suspicious activity`,
          retry_after: remainingTime
        });
      }
      
      // ðŸ”¥ NEW: Check if device is blocked
      if (deviceId && this.isDeviceBlocked(deviceId)) {
        const blockInfo = this.blockedDevices.get(deviceId);
        const remainingTime = Math.ceil((blockInfo.expiresAt - Date.now()) / 1000);
        
        return res.status(403).json({
          allow: false,
          reason: 'device_blocked',
          message: `Device blocked due to security incidents`,
          retry_after: remainingTime
        });
      }
      
      // Check failure count for adaptive limiting
      if (deviceId) {
        const failures = this.failureCount.get(deviceId) || 0;
        const adjustedLimit = failures > 3 ? 3 : this.baseLimit;
        req.adaptiveLimit = adjustedLimit;
      }
      
      next();
    };
  }
  
  /**
   * Record failed verification
   */
  recordFailure(deviceId) {
    const current = this.failureCount.get(deviceId) || 0;
    const newCount = current + 1;
    
    this.failureCount.set(deviceId, newCount);
    
    // Auto-block if too many failures
    if (newCount >= 10) {
      this.blockDevice(deviceId, 3600); // 1 hour block
      console.log(`ðŸš« Device auto-blocked: ${deviceId} (${newCount} failures)`);
    }
    
    // Reset after 1 hour
    setTimeout(() => {
      this.failureCount.delete(deviceId);
    }, 60 * 60 * 1000);
  }
  
  /**
   * Record successful verification
   */
  recordSuccess(deviceId) {
    this.failureCount.delete(deviceId);
  }
  
  /**
   * ðŸ”¥ NEW: Block IP address
   * @param {string} ip - IP address to block
   * @param {number} durationSeconds - Block duration in seconds
   */
  blockIP(ip, durationSeconds = 3600) {
    const expiresAt = Date.now() + (durationSeconds * 1000);
    
    this.blockedIPs.set(ip, {
      ip,
      blockedAt: Date.now(),
      expiresAt,
      reason: 'SECURITY_INCIDENT',
    });
    
    console.log(`ðŸš« IP Blocked: ${ip} for ${durationSeconds}s`);
    
    // Auto-remove after duration
    setTimeout(() => {
      this.blockedIPs.delete(ip);
      console.log(`âœ… IP Unblocked: ${ip}`);
    }, durationSeconds * 1000);
  }
  
  /**
   * ðŸ”¥ NEW: Block device
   */
  blockDevice(deviceId, durationSeconds = 3600) {
    const expiresAt = Date.now() + (durationSeconds * 1000);
    
    this.blockedDevices.set(deviceId, {
      deviceId,
      blockedAt: Date.now(),
      expiresAt,
      reason: 'EXCESSIVE_FAILURES',
    });
    
    console.log(`ðŸš« Device Blocked: ${deviceId} for ${durationSeconds}s`);
    
    setTimeout(() => {
      this.blockedDevices.delete(deviceId);
      console.log(`âœ… Device Unblocked: ${deviceId}`);
    }, durationSeconds * 1000);
  }
  
  /**
   * ðŸ”¥ NEW: Check if IP is blocked
   */
  isIPBlocked(ip) {
    const blockInfo = this.blockedIPs.get(ip);
    
    if (!blockInfo) return false;
    
    // Check if block expired
    if (Date.now() > blockInfo.expiresAt) {
      this.blockedIPs.delete(ip);
      return false;
    }
    
    return true;
  }
  
  /**
   * ðŸ”¥ NEW: Check if device is blocked
   */
  isDeviceBlocked(deviceId) {
    const blockInfo = this.blockedDevices.get(deviceId);
    
    if (!blockInfo) return false;
    
    if (Date.now() > blockInfo.expiresAt) {
      this.blockedDevices.delete(deviceId);
      return false;
    }
    
    return true;
  }
  
  /**
   * ðŸ”¥ NEW: Get current block statistics
   */
  getStats() {
    return {
      blockedIPs: this.blockedIPs.size,
      blockedDevices: this.blockedDevices.size,
      devicesWithFailures: this.failureCount.size,
    };
  }
  
  /**
   * Cleanup expired entries
   */
  cleanup() {
    const now = Date.now();
    
    // Clean expired IP blocks
    for (const [ip, info] of this.blockedIPs.entries()) {
      if (now > info.expiresAt) {
        this.blockedIPs.delete(ip);
      }
    }
    
    // Clean expired device blocks
    for (const [deviceId, info] of this.blockedDevices.entries()) {
      if (now > info.expiresAt) {
        this.blockedDevices.delete(deviceId);
      }
    }
    
    console.log('ðŸ§¹ Rate limiter cleanup completed');
  }
  
  /**
   * ðŸ”¥ NEW: Manual unblock (admin action)
   */
  unblockIP(ip) {
    const wasBlocked = this.blockedIPs.has(ip);
    this.blockedIPs.delete(ip);
    return wasBlocked;
  }
  
  unblockDevice(deviceId) {
    const wasBlocked = this.blockedDevices.has(deviceId);
    this.blockedDevices.delete(deviceId);
    this.failureCount.delete(deviceId);
    return wasBlocked;
  }
}

const adaptiveRateLimiter = new AdaptiveRateLimiter();

// ðŸ”¥ NEW: Admin endpoint helper for stats
function getRateLimitStats() {
  return {
    adaptive: adaptiveRateLimiter.getStats(),
    timestamp: new Date().toISOString(),
  };
}

module.exports = {
  deviceRateLimiter,
  ipRateLimiter,
  adaptiveRateLimiter,
  redisClient,
  getRateLimitStats, // ðŸ”¥ NEW export
};
