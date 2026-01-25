// 📂 lib/cryptex_lock/src/motion_models.dart
import 'cla_models.dart';

// ✅ ALIAS: Supaya kod lama yang panggil 'MotionData' tak error
typedef MotionData = MotionEvent;
typedef TouchData = TouchEvent;

/// Raw motion sensor reading
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

  Map<String, dynamic> toJson() => {
    'm': magnitude.toStringAsFixed(4),
    't': timestamp.millisecondsSinceEpoch,
    'dx': deltaX.toStringAsFixed(4),
    'dy': deltaY.toStringAsFixed(4),
    'dz': deltaZ.toStringAsFixed(4),
  };
}

/// Raw touch sensor reading
class TouchEvent {
  final double pressure;
  final DateTime timestamp;
  final double x;
  final double y;
  final double velocityX;
  final double velocityY;

  TouchEvent({
    required this.pressure,
    required this.timestamp,
    required this.x,
    required this.y,
    this.velocityX = 0,
    this.velocityY = 0,
  });
  
  Map<String, dynamic> toJson() => {
    'p': pressure.toStringAsFixed(3),
    't': timestamp.millisecondsSinceEpoch,
    'x': x.toStringAsFixed(1),
    'y': y.toStringAsFixed(1),
    'vx': velocityX.toStringAsFixed(2),
    'vy': velocityY.toStringAsFixed(2),
  };
}

/// ✅ CRITICAL: Object ini yang hilang tadi!
class ValidationAttempt {
  final String attemptId;
  final List<int> inputCode;
  final BiometricData? biometricData;
  final bool hasPhysicalMovement;
  final DateTime timestamp;

  ValidationAttempt({
    required this.attemptId,
    required this.inputCode,
    this.biometricData,
    this.hasPhysicalMovement = false,
    required this.timestamp,
  });
}

/// ✅ CRITICAL: Biometric Data Wrapper
class BiometricData {
  final List<MotionEvent> motionEvents;
  final List<TouchEvent> touchEvents;
  final double entropy;

  BiometricData({
    required this.motionEvents,
    required this.touchEvents,
    this.entropy = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'motion_count': motionEvents.length,
    'touch_count': touchEvents.length,
    'entropy': entropy,
  };
}

/// ✅ CRITICAL: Validation Result
class ValidationResult {
  final bool allowed;
  final SecurityState newState;
  final ThreatLevel threatLevel;
  final String reason;
  final double confidence;
  final Map<String, dynamic> metadata;

  ValidationResult({
    required this.allowed,
    required this.newState,
    required this.threatLevel,
    required this.reason,
    required this.confidence,
    this.metadata = const {},
  });

  factory ValidationResult.success({required double confidence, bool isPanicMode = false}) {
    return ValidationResult(
      allowed: true,
      newState: SecurityState.UNLOCKED,
      threatLevel: ThreatLevel.SAFE,
      reason: isPanicMode ? 'PANIC_MODE' : 'VERIFIED',
      confidence: confidence,
    );
  }

  factory ValidationResult.denied({required String reason, required ThreatLevel threatLevel, double confidence = 0.0}) {
    return ValidationResult(
      allowed: false,
      newState: SecurityState.SOFT_LOCK,
      threatLevel: threatLevel,
      reason: reason,
      confidence: confidence,
    );
  }
}
