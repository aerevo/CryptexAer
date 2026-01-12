// 📦 Z-KINETIC MODELS V5.6 - "THE STATELESS REQUIREMENTS"
// Integrity: 101% - NO TRUNCATION.

import 'package:flutter/foundation.dart';

enum SecurityState { LOCKED, VALIDATING, UNLOCKED, SOFT_LOCK, HARD_LOCK }

class MotionEvent {
  final double magnitude;
  final DateTime timestamp;
  final double deltaX;
  final double deltaY;
  final double deltaZ;

  MotionEvent({
    required this.magnitude,
    required this.timestamp,
    this.deltaX = 0,
    this.deltaY = 0,
    this.deltaZ = 0,
  });
}

class SecurityConfig {
  final bool enableServerValidation;
  final String mirrorEndpoint;

  const SecurityConfig({
    this.enableServerValidation = false,
    this.mirrorEndpoint = '',
  });
}

class ClaConfig {
  final List<int> secret;
  final Duration minSolveTime;
  final double minShake;
  final Duration jamCooldown;
  final Duration softLockCooldown;
  final int maxAttempts;
  final double thresholdAmount;
  final bool enableSensors;
  final double botDetectionSensitivity;
  final SecurityConfig? securityConfig;
  
  // 🔥 NEW FOR V5.6 TELEMETRY
  final String clientId;     // E.g., 'BANK_ISLAM_APP'
  final String clientSecret; // HMAC Secret Key (KEEP PRIVATE)

  const ClaConfig({
    required this.secret,
    required this.minSolveTime,
    required this.minShake,
    this.jamCooldown = const Duration(seconds: 30),
    this.softLockCooldown = const Duration(seconds: 2),
    this.maxAttempts = 3,
    required this.thresholdAmount,
    this.enableSensors = true,
    this.botDetectionSensitivity = 0.4,
    this.securityConfig,
    
    // Default credentials for testing
    this.clientId = 'CRYPTER_DEMO',
    this.clientSecret = 'zk_kinetic_default_secret_2026', 
  });
}
