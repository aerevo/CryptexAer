# 🔐 CryptexLock Integration Guide

Complete guide untuk integrate server-validated security system.

---

## 📦 **STEP 1: Setup Dependencies**

### Flutter (Client)

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  sensors_plus: ^4.0.0
  shared_preferences: ^2.2.2
  flutter_jailbreak_detection: ^1.11.0
  device_info_plus: ^9.1.1
  http: ^1.1.0
  crypto: ^3.0.3
```

Install:
```bash
flutter pub get
```

### Node.js (Server)

```bash
cd server
npm install
```

---

## 🎯 **STEP 2: Client Configuration**

### Option A: Without Server (Local Only)

```dart
import 'cla_controller.dart';
import 'cla_models.dart';

// Basic config - no server validation
final controller = ClaController(
  ClaConfig(
    secret: [1, 2, 3, 4, 5],
    minSolveTime: Duration(seconds: 2),
    minShake: 0.5,
    jamCooldown: Duration(seconds: 30),
    thresholdAmount: 1.0,
    enableSensors: true,
    botDetectionSensitivity: 0.85,
    // No securityConfig = local validation only
  ),
);
```

### Option B: With Server Validation

```dart
import 'cla_controller.dart';
import 'cla_models.dart';
import 'security/config/security_config.dart';

// Production config with server
final controller = ClaController(
  ClaConfig(
    secret: [1, 2, 3, 4, 5],
    minSolveTime: Duration(seconds: 2),
    minShake: 0.5,
    jamCooldown: Duration(seconds: 30),
    thresholdAmount: 1.0,
    enableSensors: true,
    botDetectionSensitivity: 0.85,
    // ✨ Enable server validation
    securityConfig: SecurityConfig.production(
      serverEndpoint: 'https://api.yourdomain.com',
    ),
  ),
);
```

### Option C: Strict Mode (No Offline Fallback)

```dart
// Maximum security - requires server
securityConfig: SecurityConfig.strict(
  serverEndpoint: 'https://api.yourdomain.com',
),
```

---

## 🖥️ **STEP 3: Server Setup**

### 1. Configure Environment

```bash
cd server
cp .env.example .env
```

Edit `.env`:
```bash
NODE_ENV=production
PORT=3000

# Generate secrets:
# node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
HMAC_SECRET=your_generated_secret_here
JWT_SECRET=your_generated_secret_here

# Thresholds
MIN_CONFIDENCE_SCORE=0.85
RATE_LIMIT_MAX_REQUESTS=5
```

### 2. Start Server

```bash
# Development
npm run dev

# Production
npm start

# Or with PM2
pm2 start server.js --name cryptex-mirror
```

### 3. Test Server

```bash
curl http://localhost:3000/health

# Should return:
# {"status":"healthy","timestamp":"...","version":"2.0.4"}
```

---

## 🔄 **STEP 4: Usage Examples**

### Basic Usage (No Changes to Your Code!)

```dart
// Your existing code works as-is!
CryptexLock(
  controller: controller,
  onSuccess: () {
    print('✅ Unlocked!');
    // Your success logic
  },
  onFail: () {
    print('❌ Failed!');
  },
  onJammed: () {
    print('🔒 Locked out!');
  },
)
```

**That's it!** Server validation happens automatically if enabled in config.

---

## 🧪 **STEP 5: Testing**

### Test 1: Local Validation Only

```dart
// Disable server temporarily
final controller = ClaController(
  ClaConfig(
    // ... your config ...
    securityConfig: SecurityConfig.development(), // No server
  ),
);

// Should work offline
```

### Test 2: Server Validation

```dart
// Enable server
securityConfig: SecurityConfig.production(
  serverEndpoint: 'http://localhost:3000', // Test locally first
),

// Try authentication - check server logs
```

### Test 3: Server Down (Fallback)

```bash
# Stop server
pm2 stop cryptex-mirror

# App should still work (fallback to local validation)
```

### Test 4: Rate Limiting

```dart
// Try 6+ rapid attempts
// Should get rate limited after 5 attempts
```

---

## 📊 **STEP 6: Monitoring**

### Client-Side Logs

```dart
// Enable debug mode
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('Server validation enabled: ${config.hasServerValidation}');
}
```

### Server-Side Logs

```bash
# Watch logs
pm2 logs cryptex-mirror

# Or
tail -f logs/app.log
```

### Check Stats

```bash
# Server health
curl https://api.yourdomain.com/health

# Redis (if enabled)
redis-cli
> KEYS cryptex_rl:*
```

---

## 🚀 **STEP 7: Production Deployment**

### 1. Deploy Server

```bash
# Option A: VPS/Dedicated
pm2 start server.js --name cryptex-mirror
pm2 startup
pm2 save

# Option B: Docker
docker build -t cryptexlock-server .
docker run -d -p 3000:3000 cryptexlock-server

# Option C: Cloud (Heroku, AWS, GCP)
git push heroku main
```

### 2. Setup HTTPS

```nginx
# Nginx reverse proxy
server {
    listen 443 ssl;
    server_name api.yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 3. Update Flutter App

```dart
// Change to production endpoint
securityConfig: SecurityConfig.production(
  serverEndpoint: 'https://api.yourdomain.com', // Your domain
),
```

### 4. Build Release APK

```bash
flutter build apk --release --obfuscate --split-debug-info=./debug_info
```

---

## 🔧 **STEP 8: Customization**

### Adjust Biometric Thresholds

**Server (`.env`):**
```bash
MIN_CONFIDENCE_SCORE=0.90  # More strict
MIN_ENTROPY=0.6
MIN_TREMOR_HZ=8.0
```

**Client:**
```dart
ClaConfig(
  botDetectionSensitivity: 0.90, // Match server
)
```

### Adjust Rate Limits

```bash
# .env
RATE_LIMIT_MAX_REQUESTS=10  # More lenient
RATE_LIMIT_WINDOW_MS=600000  # 10 minutes
```

---

## 🐛 **Troubleshooting**

### Issue: "Server unavailable" but server is running

**Solution:**
```dart
// Check endpoint URL
print(config.securityConfig?.serverEndpoint);

// Test manually
curl https://api.yourdomain.com/health
```

### Issue: Always getting denied

**Solution:**
```bash
# Lower thresholds temporarily
# .env
MIN_CONFIDENCE_SCORE=0.70
```

### Issue: Too many rate limit errors

**Solution:**
```bash
# Increase limits
RATE_LIMIT_MAX_REQUESTS=10
```

### Issue: Timeout errors

**Solution:**
```dart
// Increase timeout
SecurityConfig(
  serverTimeout: Duration(seconds: 10), // Increased
)
```

---

## 📈 **Performance Tips**

### 1. Cache Device Fingerprint

Device fingerprint is cached automatically in `SharedPreferences`.

### 2. Use Redis for Scaling

```bash
# Enable Redis
REDIS_ENABLED=true
REDIS_URL=redis://localhost:6379
```

### 3. CDN for API

Use CloudFlare or AWS CloudFront in front of API.

---

## 🔐 **Security Checklist**

- [ ] HTTPS enabled (SSL certificate)
- [ ] Firewall configured (only 80/443 open)
- [ ] Strong secrets generated (HMAC_SECRET, JWT_SECRET)
- [ ] Rate limiting enabled
- [ ] Server logs monitored
- [ ] Backups configured
- [ ] Auto-updates enabled (PM2)

---

## 📞 **Need Help?**

**Common Questions:**

**Q: Do I need a server?**
A: No! Server validation is optional. App works fully offline.

**Q: What if server goes down?**
A: App automatically falls back to local validation (if `allowOfflineFallback: true`).

**Q: How much does hosting cost?**
A: ~$5-10/month for small VPS (DigitalOcean, Linode, etc.)

**Q: Can I self-host?**
A: Yes! Deploy on your own server, complete control.

---

## 🎉 **You're Done!**

Your CryptexLock is now **enterprise-grade** with server-side validation!

**Next Steps:**
1. Test thoroughly
2. Deploy to production
3. Monitor performance
4. Iterate and improve

**Good luck! 🚀**
