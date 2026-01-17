// 📦 Z-KINETIC MODELS (SYNCED V3.2)
// Status: CIRCULAR DEPENDENCY FIXED ✅
// Role: Define contracts clearly. Clean Architecture enforced.

import 'package:flutter/foundation.dart';

// Note: Removed import to security_config.dart to prevent circular dependency crash.
// The SecurityConfig reference in ClaConfig has been decoupled.

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

  // Helper untuk debugging/logging
  Map<String, dynamic> toJson() => {
    'm': magnitude.toStringAsFixed(4),
    't': timestamp.toIso8601String(),
    'dx': deltaX.toStringAsFixed(4),
    'dy': deltaY.toStringAsFixed(4),
    'dz': deltaZ.toStringAsFixed(4),
  };
}

class SecurityEngineConfig {
  final double minEntropy;
  final double minVariance;
  final double minConfidence;
  final double minMotionPresence;
  final double botThreshold;

  const SecurityEngineConfig({
    this.minEntropy = 0.15,
    this.minVariance = 0.005,
    this.minConfidence = 0.30,
    this.minMotionPresence = 0.05,
    this.botThreshold = 0.4,
  });
}

class ClaConfig {
  // A. Core Settings
  final List<int> secret;
  final Duration minSolveTime;
  final double minShake;
  final double thresholdAmount; 
  final int maxAttempts;
  
  // B. Cooldowns
  final Duration jamCooldown;
  final Duration softLockCooldown;
  
  // C. Feature Flags
  final bool enableSensors;
  
  // D. Identity
  final String clientId;
  final String clientSecret;

  // E. SUB-CONFIGS
  // Removed direct strict typing to prevent circular dependency
  // final SecurityConfig? securityConfig; 
  final SecurityEngineConfig engineConfig;    
  
  // F. Bot Detection
  final double botDetectionSensitivity;

  const ClaConfig({
    required this.secret,
    required this.minSolveTime,
    required this.minShake,
    required this.thresholdAmount,
    this.maxAttempts = 3,
    this.jamCooldown = const Duration(seconds: 30),
    this.softLockCooldown = const Duration(seconds: 2),
    this.enableSensors = true,
    this.clientId = 'default_client',
    this.clientSecret = '',
    this.engineConfig = const SecurityEngineConfig(),
    this.botDetectionSensitivity = 1.0,
  });
}
