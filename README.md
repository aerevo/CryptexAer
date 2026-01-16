# 🛡️ Z-KINETIC INTELLIGENCE HUB (SDK V4.5)

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![Security Level](https://img.shields.io/badge/security-MILITARY__GRADE-red)]()
[![Platform](https://img.shields.io/badge/platform-FLUTTER-blue)]()
[![License](https://img.shields.io/badge/license-PROPRIETARY-black)]()

> **The World's First Transaction-Integrity Security Suite.** > *Detects Bots. Blocks MITM Attacks. Secures High-Value Transactions.*

---

## 📋 Executive Summary

Z-KINETIC is not just a biometric lock; it is a **forensic intelligence engine**. Unlike standard 2FA (OTP/FaceID), Z-KINETIC validates the **integrity of the transaction data itself** using a proprietary zero-knowledge proof mechanism combined with behavioral biometrics.

### 🚀 Key Capabilities
* **Behavioral Biometrics:** Distinguishes human micro-tremors from robotic emulation (Auto-Clickers/ADB).
* **Integrity Verification:** Detects if displayed data (e.g., "RM 50,000") matches the secure backend signature.
* **Smart Warning System:** Warns users of potential breaches without blocking legitimate access (Production-Ready UX).
* **Offline Forensics:** Logs attack vectors locally when the device is offline, syncing to HQ upon reconnection.
* **Clean Architecture:** Fully decoupled Data Pipeline via `TransactionService`.

---

## 📦 Installation

Add the Z-KINETIC module to your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Core Sensors
  sensors_plus: ^3.0.0
  # Secure Storage
  flutter_secure_storage: ^8.0.0
  # Cryptography
  crypto: ^3.0.0
