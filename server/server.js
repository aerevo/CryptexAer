/**
 * Z-KINETIC AUTHORITY SERVER v3.0
 * ============================================================
 * Features:
 * - Server-side challenge generation
 * - Nonce + anti-replay protection
 * - Biometric risk scoring
 * - Rate limiting
 * - API Key per client ← NEW
 * - Client management (add/block/renew) ← NEW
 * - Usage tracking per client ← NEW
 * - Admin dashboard API ← NEW
 * - Auto-cleanup memory
 * ============================================================
 */

const express = require('express');
const crypto  = require('crypto');
const rateLimit = require('express-rate-limit');
const cors    = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// ============================================================
// ADMIN PASSWORD (Captain tukar nilai ni!)
// ============================================================

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'zkinetic-admin-2026';

// ============================================================
// IN-MEMORY DATABASE
// ============================================================

// Challenges & sessions (sementara - clear bila restart)
const activeChallenges = new Map();
const sessions         = new Map();

// CLIENT DATABASE
// Structure:
// clients[apiKey] = {
//   apiKey, name, plan, status,
//   createdAt, expiresAt,
//   monthlyLimit, usedThisMonth,
//   lastResetMonth, totalVerifications
// }
const clients = new Map();

// USAGE LOG (last 1000 entries)
const usageLog = [];
const MAX_LOG = 1000;

// SERVER STATS
const stats = {
  totalChallenges      : 0,
  totalVerifications   : 0,
  successfulVerifications: 0,
  failedVerifications  : 0,
  blockedRequests      : 0,
  serverStartTime      : Date.now(),
};

// ============================================================
// HELPER: GENERATE API KEY
// ============================================================

function generateApiKey() {
  const random = crypto.randomBytes(16).toString('hex');
  return `zk_live_${random}`;
}

// ============================================================
// HELPER: LOG USAGE
// ============================================================

function logUsage(apiKey, action, result, details = {}) {
  const entry = {
    timestamp : Date.now(),
    apiKey    : apiKey ? apiKey.substring(0, 20) + '...' : 'UNKNOWN',
    action,
    result,
    ...details,
  };
  usageLog.unshift(entry);
  if (usageLog.length > MAX_LOG) usageLog.pop();
}

// ============================================================
// HELPER: RESET MONTHLY USAGE (auto bila bulan baru)
// ============================================================

function checkMonthlyReset(client) {
  const now       = new Date();
  const thisMonth = `${now.getFullYear()}-${now.getMonth()}`;
  if (client.lastResetMonth !== thisMonth) {
    client.usedThisMonth  = 0;
    client.lastResetMonth = thisMonth;
  }
}

// ============================================================
// MIDDLEWARE: VALIDATE API KEY
// ============================================================

function validateApiKey(req, res, next) {
  // Captain boleh akses tanpa API key (untuk testing)
  const apiKey = req.headers['x-api-key'] || req.body?.apiKey;

  if (!apiKey) {
    stats.blockedRequests++;
    return res.status(401).json({
      success : false,
      error   : 'Missing API Key. Include x-api-key header.',
      code    : 'NO_API_KEY',
    });
  }

  const client = clients.get(apiKey);

  if (!client) {
    stats.blockedRequests++;
    logUsage(apiKey, 'challenge', 'BLOCKED', { reason: 'Invalid key' });
    return res.status(401).json({
      success : false,
      error   : 'Invalid API Key.',
      code    : 'INVALID_KEY',
    });
  }

  // Check status
  if (client.status !== 'active') {
    stats.blockedRequests++;
    logUsage(apiKey, 'challenge', 'BLOCKED', { reason: `Status: ${client.status}` });
    return res.status(403).json({
      success : false,
      error   : `Account ${client.status}. Please contact support.`,
      code    : 'ACCOUNT_' + client.status.toUpperCase(),
    });
  }

  // Check expiry
  if (client.expiresAt && Date.now() > client.expiresAt) {
    client.status = 'expired';
    stats.blockedRequests++;
    logUsage(apiKey, 'challenge', 'BLOCKED', { reason: 'Expired' });
    return res.status(403).json({
      success : false,
      error   : 'Subscription expired. Please renew.',
      code    : 'SUBSCRIPTION_EXPIRED',
    });
  }

  // Check monthly limit
  checkMonthlyReset(client);
  if (client.monthlyLimit > 0 && client.usedThisMonth >= client.monthlyLimit) {
    stats.blockedRequests++;
    logUsage(apiKey, 'challenge', 'BLOCKED', { reason: 'Limit reached' });
    return res.status(429).json({
      success : false,
      error   : `Monthly limit reached (${client.monthlyLimit} verifications).`,
      code    : 'LIMIT_REACHED',
      used    : client.usedThisMonth,
      limit   : client.monthlyLimit,
    });
  }

  // Attach client to request
  req.client = client;
  next();
}

// ============================================================
// MIDDLEWARE: VALIDATE ADMIN PASSWORD
// ============================================================

function validateAdmin(req, res, next) {
  const password = req.headers['x-admin-password'] || req.body?.adminPassword;
  if (password !== ADMIN_PASSWORD) {
    return res.status(401).json({
      success : false,
      error   : 'Invalid admin password.',
    });
  }
  next();
}

// ============================================================
// AUTO-CLEANUP (Every minute)
// ============================================================

setInterval(() => {
  const now = Date.now();
  let deletedChallenges = 0;
  let deletedSessions   = 0;

  for (const [nonce, data] of activeChallenges.entries()) {
    if (data.expiry < now) { activeChallenges.delete(nonce); deletedChallenges++; }
  }
  for (const [token, data] of sessions.entries()) {
    if (data.expiry < now) { sessions.delete(token); deletedSessions++; }
  }

  if (deletedChallenges > 0 || deletedSessions > 0) {
    console.log(`🧹 Cleanup: ${deletedChallenges} challenges, ${deletedSessions} sessions`);
  }
}, 60 * 1000);

// ============================================================
// RATE LIMITING
// ============================================================

const challengeLimiter = rateLimit({ windowMs: 60 * 1000, max: 30 });
const verifyLimiter    = rateLimit({ windowMs: 60 * 1000, max: 30 });
const adminLimiter     = rateLimit({ windowMs: 60 * 1000, max: 60 });

// ============================================================
// ENDPOINT 1: GET CHALLENGE
// /api/v1/challenge
// ============================================================

app.post('/api/v1/challenge', challengeLimiter, validateApiKey, (req, res) => {
  try {
    const client = req.client;

    // Generate 3-digit code
    const secretCode = Array.from({ length: 3 }, () => Math.floor(Math.random() * 10));
    const nonce      = crypto.randomBytes(16).toString('hex');
    const now        = Date.now();
    const expiry     = now + (60 * 1000); // 60 seconds

    activeChallenges.set(nonce, {
      code      : secretCode,
      expiry,
      used      : false,
      createdAt : now,
      apiKey    : client.apiKey,
      clientName: client.name,
    });

    stats.totalChallenges++;
    console.log(`🔑 [${client.name}] Challenge: ${secretCode.join('-')} | Nonce: ${nonce.substring(0, 8)}...`);

    res.json({
      success       : true,
      nonce,
      challengeCode : secretCode,
      expiry,
    });

  } catch (error) {
    console.error('❌ challenge error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ============================================================
// ENDPOINT 2: VERIFY
// /api/v1/verify
// ============================================================

app.post('/api/v1/verify', verifyLimiter, validateApiKey, (req, res) => {
  try {
    const { nonce, userResponse, biometricData } = req.body;
    const client = req.client;

    if (!nonce || !userResponse || !biometricData) {
      return res.status(400).json({ success: false, error: 'Missing fields: nonce, userResponse, biometricData' });
    }

    // Get challenge
    const challengeData = activeChallenges.get(nonce);
    if (!challengeData) {
      return res.status(403).json({ success: false, error: 'Invalid or expired nonce' });
    }

    // Check API key matches (prevent key mixing)
    if (challengeData.apiKey !== client.apiKey) {
      return res.status(403).json({ success: false, error: 'API key mismatch' });
    }

    // Replay attack check
    if (challengeData.used) {
      stats.failedVerifications++;
      return res.status(403).json({ success: false, error: 'Nonce already used' });
    }

    // Expiry check
    const now = Date.now();
    if (challengeData.expiry < now) {
      activeChallenges.delete(nonce);
      stats.failedVerifications++;
      return res.status(403).json({ success: false, error: 'Challenge expired' });
    }

    // Mark used
    challengeData.used = true;
    activeChallenges.delete(nonce);

    // Compare codes
    const serverCode = challengeData.code.join('');
    const userCode   = Array.isArray(userResponse) ? userResponse.join('') : '';

    console.log(`📡 [${client.name}] Verify: Expected=${serverCode} | Got=${userCode}`);

    // Biometric check
    const { motion = 0, touch = 0, pattern = 0 } = biometricData || {};
    const motionOK  = motion  > 0.15;
    const touchOK   = touch   > 0.15;
    const patternOK = pattern > 0.10;
    const sensorsActive = [motionOK, touchOK, patternOK].filter(Boolean).length;

    const codeMatch = userCode === serverCode;

    // Suspicious log
    if (!motionOK) console.log(`⚠️  [${client.name}] Suspicious: No motion detected`);

    if (codeMatch && sensorsActive >= 1) {
      // ✅ SUCCESS
      const avgScore = (motion + touch + pattern) / 3;
      const riskScore = avgScore > 0.7 ? 'LOW' : avgScore > 0.4 ? 'MEDIUM' : 'HIGH';

      // Update client usage
      checkMonthlyReset(client);
      client.usedThisMonth++;
      client.totalVerifications++;

      stats.totalVerifications++;
      stats.successfulVerifications++;

      logUsage(client.apiKey, 'verify', 'SUCCESS', {
        clientName : client.name,
        riskScore,
      });

      console.log(`✅ HUMAN VERIFIED | [${client.name}] | Risk=${riskScore} | Monthly=${client.usedThisMonth}/${client.monthlyLimit || '∞'}`);

      return res.json({
        success  : true,
        allowed  : true,
        riskScore,
        clientName: client.name,
      });

    } else {
      // ❌ FAILED
      const reasons = [];
      if (!codeMatch)   reasons.push('Wrong code');
      if (!motionOK)    reasons.push('No motion');
      if (!touchOK)     reasons.push('No touch');
      if (!patternOK)   reasons.push('No pattern');

      stats.totalVerifications++;
      stats.failedVerifications++;

      logUsage(client.apiKey, 'verify', 'FAILED', {
        clientName : client.name,
        reasons,
      });

      console.log(`❌ FAILED | [${client.name}] | ${reasons.join(', ')}`);

      return res.status(401).json({
        success : false,
        allowed : false,
        error   : 'Verification failed',
        reasons,
      });
    }

  } catch (error) {
    console.error('❌ verify error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ============================================================
// ADMIN ENDPOINTS
// Header: x-admin-password: <ADMIN_PASSWORD>
// ============================================================

// ── LIST ALL CLIENTS ─────────────────────────────────────────
app.get('/admin/clients', adminLimiter, validateAdmin, (req, res) => {
  const list = Array.from(clients.values()).map(c => {
    checkMonthlyReset(c);
    return {
      apiKey            : c.apiKey,
      name              : c.name,
      plan              : c.plan,
      status            : c.status,
      createdAt         : c.createdAt,
      expiresAt         : c.expiresAt,
      monthlyLimit      : c.monthlyLimit,
      usedThisMonth     : c.usedThisMonth,
      totalVerifications: c.totalVerifications,
      daysLeft          : c.expiresAt ? Math.max(0, Math.ceil((c.expiresAt - Date.now()) / 86400000)) : null,
    };
  });

  res.json({ success: true, total: list.length, clients: list });
});

// ── ADD NEW CLIENT ────────────────────────────────────────────
app.post('/admin/clients/add', adminLimiter, validateAdmin, (req, res) => {
  try {
    const { name, plan, monthlyLimit, durationDays } = req.body;

    if (!name) {
      return res.status(400).json({ success: false, error: 'name required' });
    }

    const PLANS = {
      starter   : { monthlyLimit: 5000,   label: 'Starter'    },
      business  : { monthlyLimit: 20000,  label: 'Business'   },
      enterprise: { monthlyLimit: 100000, label: 'Enterprise' },
      unlimited : { monthlyLimit: 0,      label: 'Unlimited'  },
    };

    const selectedPlan = PLANS[plan] || PLANS.starter;
    const apiKey       = generateApiKey();
    const now          = Date.now();
    const days         = durationDays || 30;
    const now_date     = new Date();
    const thisMonth    = `${now_date.getFullYear()}-${now_date.getMonth()}`;

    const newClient = {
      apiKey,
      name,
      plan              : plan || 'starter',
      status            : 'active',
      createdAt         : now,
      expiresAt         : now + (days * 86400000),
      monthlyLimit      : monthlyLimit || selectedPlan.monthlyLimit,
      usedThisMonth     : 0,
      lastResetMonth    : thisMonth,
      totalVerifications: 0,
    };

    clients.set(apiKey, newClient);

    console.log(`➕ NEW CLIENT: ${name} | Plan: ${plan} | Key: ${apiKey.substring(0, 20)}...`);

    res.json({
      success  : true,
      message  : `Client "${name}" created successfully!`,
      apiKey,
      expiresAt: newClient.expiresAt,
      plan     : selectedPlan.label,
      monthlyLimit: newClient.monthlyLimit,
    });

  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ── BLOCK CLIENT ──────────────────────────────────────────────
app.post('/admin/clients/block', adminLimiter, validateAdmin, (req, res) => {
  const { apiKey } = req.body;
  const client = clients.get(apiKey);

  if (!client) return res.status(404).json({ success: false, error: 'Client not found' });

  client.status = 'blocked';
  console.log(`🚫 BLOCKED: ${client.name}`);
  res.json({ success: true, message: `Client "${client.name}" blocked.` });
});

// ── UNBLOCK CLIENT ────────────────────────────────────────────
app.post('/admin/clients/unblock', adminLimiter, validateAdmin, (req, res) => {
  const { apiKey } = req.body;
  const client = clients.get(apiKey);

  if (!client) return res.status(404).json({ success: false, error: 'Client not found' });

  client.status = 'active';
  console.log(`✅ UNBLOCKED: ${client.name}`);
  res.json({ success: true, message: `Client "${client.name}" unblocked.` });
});

// ── RENEW CLIENT ──────────────────────────────────────────────
app.post('/admin/clients/renew', adminLimiter, validateAdmin, (req, res) => {
  const { apiKey, durationDays } = req.body;
  const client = clients.get(apiKey);

  if (!client) return res.status(404).json({ success: false, error: 'Client not found' });

  const days        = durationDays || 30;
  const now         = Date.now();
  // Kalau dah expired, renew dari sekarang. Kalau belum, tambah dari tarikh expire
  const baseTime    = client.expiresAt > now ? client.expiresAt : now;
  client.expiresAt  = baseTime + (days * 86400000);
  client.status     = 'active';

  console.log(`🔄 RENEWED: ${client.name} | +${days} days`);
  res.json({
    success   : true,
    message   : `Client "${client.name}" renewed for ${days} days.`,
    newExpiry : client.expiresAt,
    daysLeft  : Math.ceil((client.expiresAt - now) / 86400000),
  });
});

// ── DELETE CLIENT ─────────────────────────────────────────────
app.post('/admin/clients/delete', adminLimiter, validateAdmin, (req, res) => {
  const { apiKey } = req.body;
  const client = clients.get(apiKey);

  if (!client) return res.status(404).json({ success: false, error: 'Client not found' });

  clients.delete(apiKey);
  console.log(`🗑️  DELETED: ${client.name}`);
  res.json({ success: true, message: `Client "${client.name}" deleted.` });
});

// ── UPDATE LIMIT ──────────────────────────────────────────────
app.post('/admin/clients/update-limit', adminLimiter, validateAdmin, (req, res) => {
  const { apiKey, monthlyLimit } = req.body;
  const client = clients.get(apiKey);

  if (!client) return res.status(404).json({ success: false, error: 'Client not found' });

  client.monthlyLimit = monthlyLimit;
  res.json({ success: true, message: `Limit updated to ${monthlyLimit || '∞'}/month.` });
});

// ── USAGE LOG ─────────────────────────────────────────────────
app.get('/admin/logs', adminLimiter, validateAdmin, (req, res) => {
  const limit  = parseInt(req.query.limit) || 50;
  const apiKey = req.query.apiKey;

  let logs = usageLog;
  if (apiKey) {
    logs = logs.filter(l => l.apiKey.startsWith(apiKey.substring(0, 20)));
  }

  res.json({ success: true, total: logs.length, logs: logs.slice(0, limit) });
});

// ── DASHBOARD STATS ───────────────────────────────────────────
app.get('/admin/stats', adminLimiter, validateAdmin, (req, res) => {
  const now        = Date.now();
  const clientList = Array.from(clients.values());

  const activeClients  = clientList.filter(c => c.status === 'active').length;
  const expiredClients = clientList.filter(c => c.status === 'expired' || (c.expiresAt && c.expiresAt < now)).length;
  const blockedClients = clientList.filter(c => c.status === 'blocked').length;
  const totalUsage     = clientList.reduce((sum, c) => sum + c.usedThisMonth, 0);

  res.json({
    success: true,
    server : {
      uptime  : Math.floor((now - stats.serverStartTime) / 1000),
      version : '3.0.0',
    },
    clients: {
      total  : clientList.length,
      active : activeClients,
      expired: expiredClients,
      blocked: blockedClients,
    },
    verifications: {
      total      : stats.totalVerifications,
      successful : stats.successfulVerifications,
      failed     : stats.failedVerifications,
      blocked    : stats.blockedRequests,
    },
    usageThisMonth: totalUsage,
  });
});

// ============================================================
// HEALTH CHECK (Public)
// ============================================================

app.get('/health', (req, res) => {
  res.json({
    status  : 'OK',
    server  : 'Z-Kinetic Authority v3.0',
    uptime  : Math.floor((Date.now() - stats.serverStartTime) / 1000),
    clients : clients.size,
  });
});

// ============================================================
// START SERVER
// ============================================================

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log('============================================================');
  console.log('🚀 Z-KINETIC AUTHORITY SERVER v3.0');
  console.log('============================================================');
  console.log(`📡 Server  : http://localhost:${PORT}`);
  console.log(`🔧 Health  : http://localhost:${PORT}/health`);
  console.log(`📊 Stats   : http://localhost:${PORT}/admin/stats`);
  console.log(`👥 Clients : http://localhost:${PORT}/admin/clients`);
  console.log('============================================================');
  console.log('🔑 Admin endpoints require: x-admin-password header');
  console.log('🔐 SDK endpoints require  : x-api-key header');
  console.log('============================================================');
});
