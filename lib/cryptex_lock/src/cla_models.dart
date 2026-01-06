/*
 * PROJECT: CryptexLock Security Suite
 * MODELS: Hybrid Logic + Server Validation
 * STATUS: MERGED (Francois Edition)
 */

import 'security/config/security_config.dart';

enum SecurityState {
  LOCKED,           // Sedia
  VALIDATING,       // Sedang semak
  UNLOCKED,         // Berjaya
  SOFT_LOCK,        // Salah Key in (Amaran)
  HARD_LOCK,        // Jammed (Kena tunggu)
  BOT_SIMULATION,   // Mode Test Robot
  ROOT_WARNING,     // Anjing Penjaga Menggonggong
  COMPROMISED       // Kena Block Terus
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
  
  // Advanced biometric parameters
  final double botDetectionSensitivity;
  
  // Server validation config (KEKALKAN DARI ZIP)
  final SecurityConfig? securityConfig;

  const ClaConfig({
    required this.secret,
    required this.minSolveTime,
    required this.minShake,
    required this.jamCooldown,
    this.softLockCooldown = const Duration(seconds: 3),
    this.maxAttempts = 3, 
    required this.thresholdAmount,
    this.enableSensors = true,
    this.botDetectionSensitivity = 0.4,
    this.securityConfig,
  });
  
  /// Check if server validation is enabled
  bool get hasServerValidation => 
      securityConfig != null && 
      securityConfig!.enableServerValidation &&
      securityConfig!.isValid();
}

/// Hybrid Signature (Gabungan Touch + Motion)
class BiometricSignature {
  final double touchScore;    // 80% Weight
  final double motionScore;   // 20% Weight
  final double finalConfidence;
  final DateTime timestamp;
  final bool isHumanLikely;

  BiometricSignature({
    required this.touchScore,
    required this.motionScore,
    required this.finalConfidence,
    required this.timestamp,
    required this.isHumanLikely,
  });

  // Untuk serasi dengan kod server lama (Payload), kita map nilai hybrid ke sini
  double get averageMagnitude => motionScore; // Mapping
  double get patternEntropy => touchScore;    // Mapping
}

class MotionEvent {
  final double magnitude;
  final DateTime timestamp;
  final double deltaX, deltaY, deltaZ;

  MotionEvent({
    required this.magnitude,
    required this.timestamp,
    required this.deltaX,
    required this.deltaY,
    required this.deltaZ,
  });
}
