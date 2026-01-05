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
  final double humanTremorFrequency; // Expected 8-12 Hz for human hand tremors
  final double botDetectionSensitivity; // 0.0-1.0 scale
  final int minimumGestureSequence; // Minimum unique movements required
  final Duration biometricWindowDuration; // Time window for pattern analysis

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
  });
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
    
    // Weight: Magnitude (natural human shake is 0.2-2.0)
    if (averageMagnitude > 0.15 && averageMagnitude < 3.0) score += 0.3;
    
    // Weight: Variance (humans are inconsistent)
    if (frequencyVariance > 0.1) score += 0.25;
    
    // Weight: Entropy (randomness indicator)
    if (patternEntropy > 0.5) score += 0.25;
    
    // Weight: Gesture diversity
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
