/*
 * PROJECT: CryptexLock Security Suite
 * MODELS: Extended with Server Validation Support
 */

// FIX: Buang titik (..) sebab fail ni dah duduk dalam src
import 'security/config/security_config.dart';

enum SecurityState {
  LOCKED,           // Ready for authentication
  VALIDATING,       // Processing biometric signature
  UNLOCKED,         // Access granted
  SOFT_LOCK,        // Failed attempt - warning state
  HARD_LOCK,        // Cooldown period active
  BOT_SIMULATION,   // Test mode for developers
  ROOT_WARNING,     // Security compromise detected
  COMPROMISED       // Critical security breach
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
  final double humanTremorFrequency;
  final double botDetectionSensitivity;
  final int minimumGestureSequence;
  final Duration biometricWindowDuration;
  
  // ✨ NEW: Server validation config
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
    this.humanTremorFrequency = 10.0,
    this.botDetectionSensitivity = 0.85,
    this.minimumGestureSequence = 5,
    this.biometricWindowDuration = const Duration(seconds: 2),
    // Optional server config (default null = no server validation)
    this.securityConfig,
  });
  
  /// Check if server validation is enabled
  bool get hasServerValidation => 
      securityConfig != null && 
      securityConfig!.enableBiometrics; // Fallback check
}

/// Biometric signature snapshot
class BiometricSignature {
  final double averageMagnitude;
  final double frequencyVariance;
  final double patternEntropy;
  final int uniqueGestureCount;
  final DateTime timestamp;
  final bool isPotentiallyHuman;

  BiometricSignature({
    required this.averageMagnitude,
    required this.frequencyVariance,
    required this.patternEntropy,
    required this.uniqueGestureCount,
    required this.timestamp,
    required this.isPotentiallyHuman,
  });

  double get humanConfidence {
    double score = 0.0;
    
    if (averageMagnitude > 0.15 && averageMagnitude < 3.0) score += 0.3;
    if (frequencyVariance > 0.1) score += 0.25;
    if (patternEntropy > 0.5) score += 0.25;
    if (uniqueGestureCount >= 3) score += 0.2;
    
    return score.clamp(0.0, 1.0);
  }
}

/// Motion event for pattern analysis
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

  bool isSimilarTo(MotionEvent other, {double threshold = 0.05}) {
    double diff = (magnitude - other.magnitude).abs();
    return diff < threshold;
  }
}
