/**
 * CryptexLock Mirror Server
 * Rate Limiting Middleware
 * Prevents brute-force attacks
 */

const rateLimit = require('express-rate-limit');
const Redis = require('redis');

// Redis client (optional - for distributed systems)
let redisClient = null;

if (process.env.REDIS_ENABLED === 'true') {
  redisClient = Redis.createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379'
  });
  
  redisClient.connect().catch(console.error);
}

/**
 * Device-based rate limiter
 * Limits requests per device ID
 */
const deviceRateLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 min
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 5, // 5 attempts
  
  // Use device_id from request body
  keyGenerator: (req) => {
    return req.body?.device_id || req.ip;
  },
  
  // Custom store (Redis if enabled)
  store: redisClient ? createRedisStore() : undefined,
  
  // Response when rate limit exceeded
  handler: (req, res) => {
    res.status(429).json({
      allow: false,
      reason: 'rate_limit_exceeded',
      message: 'Too many attempts. Please try again later.',
      retry_after: req.rateLimit.resetTime
    });
  },
  
  // Skip successful requests from count
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
  
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * IP-based rate limiter (global protection)
 * More lenient than device limiter
 */
const ipRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50, // 50 requests per IP per 15 min
  
  handler: (req, res) => {
    res.status(429).json({
      allow: false,
      reason: 'ip_rate_limit_exceeded',
      message: 'Too many requests from this IP address.'
    });
  }
});

/**
 * Create Redis store for distributed rate limiting
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
 * Adaptive rate limiter
 * Adjusts limits based on failure rate
 */
class AdaptiveRateLimiter {
  constructor() {
    this.failureCount = new Map();
    this.baseLimit = 5;
  }
  
  middleware() {
    return (req, res, next) => {
      const deviceId = req.body?.device_id;
      if (!deviceId) return next();
      
      const failures = this.failureCount.get(deviceId) || 0;
      
      // If device has many failures, reduce limit
      const adjustedLimit = failures > 3 ? 3 : this.baseLimit;
      
      req.adaptiveLimit = adjustedLimit;
      next();
    };
  }
  
  recordFailure(deviceId) {
    const current = this.failureCount.get(deviceId) || 0;
    this.failureCount.set(deviceId, current + 1);
    
    // Reset after 1 hour
    setTimeout(() => {
      this.failureCount.delete(deviceId);
    }, 60 * 60 * 1000);
  }
  
  recordSuccess(deviceId) {
    // Reset on success
    this.failureCount.delete(deviceId);
  }
}

const adaptiveRateLimiter = new AdaptiveRateLimiter();

module.exports = {
  deviceRateLimiter,
  ipRateLimiter,
  adaptiveRateLimiter,
  redisClient
};
