<invoke name="artifacts">
<parameter name="command">create</parameter>
<parameter name="type">text/markdown</parameter>
<parameter name="id">z-kinetic-readme</parameter>
<parameter name="title">README.md - Z-KINETIC Documentation</parameter>
<parameter name="content"># 🛡️ Z-KINETIC INTELLIGENCE HUB V7.2

[![Security](https://img.shields.io/badge/security-MILITARY__GRADE-red)]()
[![Platform](https://img.shields.io/badge/platform-Flutter%203.x-blue)]()
[![Server](https://img.shields.io/badge/server-Node.js%2016%2B-green)]()
[![License](https://img.shields.io/badge/license-PROPRIETARY-black)]()

> **Next-Generation Transaction Security Suite**  
> *Detects Bots. Blocks MITM Attacks. Validates Data Integrity.*

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [Architecture](#-architecture)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Security Model](#-security-model)
- [API Documentation](#-api-documentation)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

---

## 🌟 Overview

Z-KINETIC is **not** a traditional biometric lock. It's an **intelligence engine** that validates:

1. **User authenticity** (human vs bot detection)
2. **Transaction integrity** (MITM attack detection)
3. **Behavioral patterns** (account takeover prevention)

### Real-World Use Case

```
🏦 Banking App Scenario:
├─ User tries to transfer RM 50,000
├─ MITM attacker changes to RM 500,000
├─ Z-KINETIC detects hash mismatch
├─ Warns user + logs incident
└─ Transaction blocked/flagged
```

---

## ✨ Key Features

### 🤖 **Bot Detection**
- Analyzes motion sensor data (tremor patterns)
- Detects auto-clickers and ADB automation
- Real-time behavioral fingerprinting

### 🔐 **MITM Protection**
- Zero-knowledge proof validation
- SHA-256 hash verification
- Nonce-based replay immunity

### 🧠 **AI Learning**
- Adapts to user behavior over time
- Z-score anomaly detection
- Personalized security thresholds

### 📊 **Incident Reporting**
- Local forensic logging (SQLite)
- Server-side threat intelligence
- Automatic blacklisting

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│          FLUTTER APP (Client)                   │
├─────────────────────────────────────────────────┤
│  UI Layer                                       │
│  ├─ CryptexLock Widget (cla_widget.dart)       │
│  └─ Lock Screen UI                             │
├─────────────────────────────────────────────────┤
│  Controller Layer                               │
│  ├─ ClaController V2 (cla_controller_v2.dart)  │
│  │  ├─ Adaptive AI Engine ✨ NEW              │
│  │  ├─ Motion/Touch Buffers                    │
│  │  └─ State Management                        │
│  └─ Transaction Service                        │
├─────────────────────────────────────────────────┤
│  Security Core (Headless)                       │
│  ├─ Behavioral Analyzer                        │
│  ├─ Adaptive Threshold Engine                  │
│  ├─ Replay Tracker                             │
│  └─ Attestation Providers                      │
├─────────────────────────────────────────────────┤
│  Data Layer                                     │
│  ├─ Incident Storage (SQLite)                  │
│  ├─ Device Fingerprint                         │
│  └─ Secure Storage                             │
└─────────────────────────────────────────────────┘
                    ▼ HTTPS ▼
┌─────────────────────────────────────────────────┐
│       NODE.JS SERVER (Mirror Service)           │
├─────────────────────────────────────────────────┤
│  ├─ Biometric Validator                        │
│  ├─ Threat Analyzer ✨ NEW                     │
│  ├─ Device Blacklist Manager                   │
│  └─ Rate Limiter (Adaptive)                    │
└─────────────────────────────────────────────────┘
```

### Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **ClaController V2** | Main orchestrator with AI | `lib/cryptex_lock/src/cla_controller_v2.dart` |
| **Security Core** | Headless validation engine | `lib/cryptex_lock/src/security_core.dart` |
| **Behavioral Analyzer** | Bot detection | `lib/cryptex_lock/src/behavioral_analyzer.dart` |
| **Adaptive Engine** | User learning | `lib/cryptex_lock/src/adaptive_threshold_engine.dart` |
| **Mirror Server** | Backend validation | `server/server.js` |

---

## 📦 Installation

### Prerequisites

```bash
# Flutter SDK
flutter --version  # >= 3.0.0

# Node.js (for server)
node --version     # >= 16.0.0
npm --version      # >= 8.0.0
```

---

### Client Setup (Flutter)

#### 1. Clone Repository
```bash
git clone https://github.com/your-org/z-kinetic.git
cd z-kinetic
```

#### 2. Install Dependencies
```bash
flutter pub get
```

#### 3. Configure App
Edit `lib/main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize incident storage
  await IncidentStorage.database;
  
  runApp(const MyApp());
}
```

#### 4. Run App
```bash
# Development
flutter run

# Production build
flutter build apk --release
flutter build ios --release
```

---

### Server Setup (Node.js)

#### 1. Navigate to Server
```bash
cd server
```

#### 2. Install Dependencies
```bash
npm install
```

#### 3. Configure Environment
```bash
cp .env.example .env
nano .env
```

**🚨 CRITICAL: Change these secrets!**

```bash
# Generate new JWT secret
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Paste result in .env
JWT_SECRET=<your_generated_secret>
HMAC_SECRET=<another_generated_secret>
```

#### 4. Start Server
```bash
# Development
npm run dev

# Production
npm start
```

#### 5. Verify Health
```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2025-01-21T10:30:00.000Z",
  "version": "3.0.0"
}
```

---

## ⚙️ Configuration

### Client Configuration

**File:** `lib/main.dart`

```dart
final config = SecurityConfig(
  // Core Settings
  enableBiometrics: true,
  maxAttempts: 5,
  lockoutDuration: const Duration(seconds: 30),
  
  // Server Integration
  enableServerValidation: true,
  serverEndpoint: "https://api.yourdomain.com",
  allowOfflineFallback: true,
  
  // Incident Reporting
  enableIncidentReporting: true,
  autoReportCriticalThreats: true,
  retryFailedReports: true,
);
```

### Server Configuration

**File:** `server/.env`

```bash
# Server
NODE_ENV=production
PORT=3000

# Security
JWT_SECRET=<64-char-hex-string>
HMAC_SECRET=<64-char-hex-string>

# Biometric Thresholds
MIN_ENTROPY=0.5
MIN_TREMOR_HZ=7.5
MAX_TREMOR_HZ=13.5
MIN_CONFIDENCE_SCORE=0.85

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000  # 15 minutes
RATE_LIMIT_MAX_REQUESTS=5
```

---

## 🚀 Usage

### Basic Integration

```dart
import 'package:your_app/cryptex_lock/cryptex_lock.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late ClaController _controller;

  @override
  void initState() {
    super.initState();
    
    // Initialize controller
    _controller = ClaController(
      ClaConfig(
        secret: [1, 7, 3, 9, 2],  // Your PIN
        enableSensors: true,
        maxAttempts: 5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CryptexLock(
        controller: _controller,
        onSuccess: _handleSuccess,
        onFail: _handleFailure,
        onJammed: _handleLockout,
      ),
    );
  }

  void _handleSuccess() {
    if (_controller.isPanicMode) {
      // Silent alarm triggered
      _sendSilentAlert();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

### Advanced: Custom Attestation

```dart
// Create custom device attestation
final deviceProvider = DeviceIntegrityAttestation(
  allowDebugMode: false,
  allowEmulators: false,
  strictMode: true,
);

// Create server attestation
final serverProvider = ServerAttestationProvider(
  ServerAttestationConfig(
    endpoint: 'https://api.yourdomain.com/v1/unlock',
    apiKey: 'YOUR_API_KEY',
  ),
);

// Combine both (composite attestation)
final compositeProvider = CompositeAttestationProvider(
  [deviceProvider, serverProvider],
  strategy: AttestationStrategy.ALL_MUST_PASS,
);

// Use in config
final controller = ClaController(
  ClaConfig(
    secret: [1, 7, 3, 9, 2],
    attestationProvider: compositeProvider,
  ),
);
```

---

## 🔒 Security Model

### Threat Detection Layers

```
┌─────────────────────────────────────┐
│  Layer 1: Motion Biometrics         │
│  ├─ Tremor frequency (8-12 Hz)      │
│  ├─ Micro-movements                 │
│  └─ Acceleration patterns           │
├─────────────────────────────────────┤
│  Layer 2: Touch Dynamics            │
│  ├─ Pressure variance               │
│  ├─ Velocity profiles               │
│  └─ Hesitation patterns             │
├─────────────────────────────────────┤
│  Layer 3: Temporal Analysis         │
│  ├─ Interaction timing              │
│  ├─ Speed consistency               │
│  └─ Pause distribution              │
├─────────────────────────────────────┤
│  Layer 4: AI Anomaly Detection      │
│  ├─ Z-score analysis (3σ)           │
│  ├─ Behavioral baseline             │
│  └─ Adaptive thresholds             │
├─────────────────────────────────────┤
│  Layer 5: Zero-Knowledge Proof      │
│  ├─ SHA-256 hash validation         │
│  ├─ Nonce-based replay immunity     │
│  └─ Server attestation              │
└─────────────────────────────────────┘
```

### Attack Resistance

| Attack Type | Detection Method | Mitigation |
|-------------|------------------|------------|
| **Auto-clicker** | Perfect timing detection | Blocked (no tremor) |
| **ADB Automation** | Constant pressure variance | Flagged as bot |
| **MITM Attack** | Hash mismatch | Transaction blocked |
| **Replay Attack** | Nonce validation | Request rejected |
| **Account Takeover** | Behavioral drift | Anomaly alert |
| **Overlay Phishing** | Value manipulation detection | User warning |

---

## 📡 API Documentation

### Client-to-Server Flow

```
Client                          Server
  │                               │
  ├─── POST /api/v1/verify ──────>│
  │    {                          │
  │      device_id,               │
  │      biometric: {...},        │
  │      zk_proof,                │
  │      nonce,                   │
  │      timestamp                │
  │    }                          │
  │                               │
  │<─── 200 OK ───────────────────┤
       {                          │
         allow: true,             │
         token: "...",            │
         confidence: 0.92         │
       }                          │
```

### Endpoints

#### `POST /api/v1/verify`
Validate biometric attempt.

**Request:**
```json
{
  "device_id": "DEVICE_abc123",
  "app_signature": "hash_value",
  "nonce": "unique_nonce",
  "timestamp": 1705843200000,
  "biometric": {
    "entropy": 0.85,
    "tremor_hz": 10.2,
    "frequency_variance": 0.15,
    "average_magnitude": 1.8,
    "unique_gesture_count": 7,
    "interaction_time_ms": 2300
  },
  "zk_proof": "sha256_hash",
  "motion_signature": "hash"
}
```

**Response (Success):**
```json
{
  "allow": true,
  "token": "jwt_token_here",
  "expires_in": 30,
  "confidence": 0.92
}
```

**Response (Failed):**
```json
{
  "allow": false,
  "reason": "low_entropy_pattern",
  "confidence": 0.35
}
```

---

#### `POST /api/v1/report-incident`
Report security incident.

**Request:**
```json
{
  "incident_id": "INC-1705843200000",
  "timestamp": "2025-01-21T10:30:00Z",
  "device_id": "DEVICE_abc123",
  "threat_intel": {
    "type": "MITM_AMOUNT_MANIPULATION",
    "original_val": "RM 50,000.00",
    "manipulated_val": "RM 500,000.00"
  },
  "action": "TRANSACTION_BLOCKED"
}
```

**Response:**
```json
{
  "success": true,
  "incident_id": "INC-1705843200000",
  "severity": "CRITICAL",
  "actions_taken": {
    "logged": true,
    "device_blacklisted": true,
    "ip_restricted": true
  }
}
```

---

## 🐛 Troubleshooting

### Common Issues

#### ❌ "INSUFFICIENT BIOMETRIC DATA"

**Cause:** Phone is stationary or user interaction too brief.

**Fix:**
```dart
// Lower threshold in development
const config = ClaConfig(
  minShake: 0.3,  // Lower from default 0.4
  thresholdAmount: 0.2,  // Lower from 0.25
);
```

---

#### ❌ "Device Blacklisted"

**Cause:** Multiple failed attempts or critical security incident.

**Fix (Development):**
```bash
# Server console
curl -X POST http://localhost:3000/admin/unblock-device \
  -H "Content-Type: application/json" \
  -d '{"device_id": "DEVICE_abc123"}'
```

---

#### ❌ Server Connection Failed

**Fix:**
```dart
// Enable offline fallback
const config = SecurityConfig(
  allowOfflineFallback: true,
);
```

Check server:
```bash
# View server logs
npm run logs:view

# Check server status
curl http://localhost:3000/health
```

---

### Debug Mode

Enable verbose logging:

```dart
// Client
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('🧠 AI Profile: ${controller.aiProfile}');
  print('📊 Session: ${controller.getSessionSnapshot()}');
}
```

```bash
# Server
LOG_LEVEL=debug npm run dev
```

---

## 📊 Performance Benchmarks

```bash
flutter test test/performance_benchmark_test.dart
```

**Expected Results:**
```
Core Validation:        < 5ms avg
Behavioral Analysis:    < 20ms avg
Anomaly Detection:      < 10ms avg
Total Validation:       < 50ms P95
Throughput:             > 100 attempts/sec
```

---

## 🧪 Testing

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## 🤝 Contributing

### Development Workflow

1. Fork repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Run tests: `flutter test`
4. Commit: `git commit -m 'Add amazing feature'`
5. Push: `git push origin feature/amazing-feature`
6. Open Pull Request

### Code Standards

- **Dart:** Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- **JavaScript:** ESLint configuration included
- **Comments:** Document all public APIs
- **Tests:** Minimum 80% coverage for new code

---

## 📄 License

**PROPRIETARY** - All rights reserved.

Contact: [your-email@domain.com](mailto:your-email@domain.com)

---

## 🙏 Credits

Built with:
- Flutter (Google)
- Express.js
- Winston (Logging)
- SQLite

Security research references:
- OWASP Mobile Security Testing Guide
- NIST Biometric Standards
- IEEE Behavioral Biometrics Papers

---

## 📞 Support

- 📧 Email: support@yourdomain.com
- 💬 Discord: [Join Server](https://discord.gg/yourserver)
- 📚 Wiki: [GitHub Wiki](https://github.com/your-org/z-kinetic/wiki)

---

**Made with ❤️ by ZyaMina Tech**</parameter>
