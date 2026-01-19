// lib/cryptex_lock/src/cla_models.dart
// ✅ FIXED: Added toCoreConfig() method for V3 compatibility

import 'security_core.dart';
import 'motion_models.dart';

enum SecurityState {
  LOCKED,
  VALIDATING,
  UNLOCKED,
  SOFT_LOCK,
  HARD_LOCK,
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
  final List<int> secret;
  final Duration minSolveTime;
  final double minShake;
  final double thresholdAmount;
  final int maxAttempts;
  final Duration jamCooldown;
  final Duration softLockCooldown;
  final bool enableSensors;
  final String clientId;
  final String clientSecret;
  final SecurityEngineConfig engineConfig;
  final AttestationProvider? attestationProvider;
  
  // ✅ NEW: V3 compatibility parameters
  final bool enforceReplayImmunity;
  final Duration nonceValidityWindow;

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
    this.attestationProvider,
    // ✅ NEW: Default values for V3
    this.enforceReplayImmunity = true,
    this.nonceValidityWindow = const Duration(seconds: 60),
  });
  
  // ✅ CRITICAL FIX: Add toCoreConfig() method for V3
  SecurityCoreConfig toCoreConfig() {
    return SecurityCoreConfig(
      expectedCode: secret,
      maxFailedAttempts: maxAttempts,
      lockoutDuration: jamCooldown,
      enforceReplayImmunity: enforceReplayImmunity,
      nonceValidityWindow: nonceValidityWindow,
      attestationProvider: attestationProvider,
    );
  }
}
