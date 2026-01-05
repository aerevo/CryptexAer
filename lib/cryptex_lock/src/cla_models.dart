import 'dart:math';

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
  final double botDetectionSensitivity;
  final bool enableSensors; // Master Switch

  const ClaConfig({
    required this.secret,
    required this.minSolveTime,
    required this.minShake,
    required this.jamCooldown,
    this.softLockCooldown = const Duration(seconds: 3),
    this.maxAttempts = 3, 
    required this.thresholdAmount,
    this.botDetectionSensitivity = 0.4,
    this.enableSensors = true,
  });
}

class MotionEvent {
  final double magnitude;
  final DateTime timestamp;
  final double deltaX;
  final double deltaY;
  final double deltaZ;

  MotionEvent({
    required this.magnitude,
    required this.timestamp,
    required this.deltaX,
    required this.deltaY,
    required this.deltaZ,
  });
}

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

  // Simple getter to normalize confidence between 0.0 and 1.0
  double get humanConfidence {
    if (!isPotentiallyHuman) return 0.0;
    // Basic heuristic: Entropy needs to be high (human jitter)
    // Variance needs to be moderate (not too robotic, not earthquake)
    double score = 0.5;
    if (patternEntropy > 1.5) score += 0.2;
    if (frequencyVariance > 0.01 && frequencyVariance < 2.0) score += 0.3;
    return score.clamp(0.0, 1.0);
  }
}
