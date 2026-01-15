// 📦 Z-KINETIC MODELS (SYNCED V3.0)
// Status: ARCHITECTURE FIXED ✅
// Role: Define contracts clearly so Controller & Engine can speak.

import 'package:flutter/foundation.dart';
import 'security/config/security_config.dart'; // Import config server/reporting

// ==========================================
// 1. DATA STRUCTURES (EVENT & STATE)
// ==========================================

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

// ==========================================
// 2. CONFIGURATION CONTRACTS
// ==========================================

/// 🔥 ENGINE CONFIG: Tetapan sensitiviti untuk SecurityEngine
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
  
  // Factory untuk tetapan ketat/longgar
  factory SecurityEngineConfig.standard() => const SecurityEngineConfig();
  factory SecurityEngineConfig.strict() => const SecurityEngineConfig(
    minEntropy: 0.3, 
    minConfidence: 0.5,
    botThreshold: 0.3
  );
}

/// 🔥 MAIN CONFIG: Config induk yang pegang semua sub-config
class ClaConfig {
  // A. Core Settings
  final List<int> secret;
  final Duration minSolveTime;
  final double minShake;
  final double thresholdAmount; // e.g. 0.25 screen height
  final int maxAttempts;
  
  // B. Cooldowns
  final Duration jamCooldown;
  final Duration softLockCooldown;
  
  // C. Feature Flags
  final bool enableSensors;
  
  // D. Identity (Telemetry)
  final String clientId;
  final String clientSecret;

  // E. SUB-CONFIGS (Punca Error Dulu: Ini wajib ada!)
  final SecurityConfig? securityConfig;       // Server & Reporting Config
  final SecurityEngineConfig engineConfig;    // Logic Config (Human/Bot)

  const ClaConfig({
    required this.secret,
    required this.minSolveTime,
    required this.minShake,
    required this.thresholdAmount,
    this.maxAttempts = 3,
    this.jamCooldown = const Duration(seconds: 30),
    this.softLockCooldown = const Duration(seconds: 2),
    this.enableSensors = true,
    this.clientId = 'DEFAULT_CLIENT',
    this.clientSecret = '',
    this.securityConfig,
    this.engineConfig = const SecurityEngineConfig(), // Default engine config
  });
}
