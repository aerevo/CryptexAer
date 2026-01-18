/*
 * PROJECT: Z-KINETIC SECURITY CORE
 * MODULE: Motion Models (Pure Dart - FIXED)
 * STATUS: BUILD ERROR RESOLVED ✅
 */

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

  double distanceTo(MotionEvent other) {
    final dx = deltaX - other.deltaX;
    final dy = deltaY - other.deltaY;
    final dz = deltaZ - other.deltaZ;
    return (dx * dx + dy * dy + dz * dz);
  }

  Map<String, dynamic> toJson() => {
    'm': magnitude.toStringAsFixed(4),
    't': timestamp.millisecondsSinceEpoch,
    'dx': deltaX.toStringAsFixed(4),
    'dy': deltaY.toStringAsFixed(4),
    'dz': deltaZ.toStringAsFixed(4),
  };

  factory MotionEvent.fromJson(Map<String, dynamic> json) {
    return MotionEvent(
      magnitude: double.parse(json['m']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['t']),
      deltaX: double.parse(json['dx']),
      deltaY: double.parse(json['dy']),
      deltaZ: double.parse(json['dz']),
    );
  }
}

/// Touch interaction event
class TouchEvent {
  final DateTime timestamp;
  final double pressure;
  final double velocityX;
  final double velocityY;

  TouchEvent({
    required this.timestamp,
    this.pressure = 0.5,
    this.velocityX = 0,
    this.velocityY = 0,
  });

  Map<String, dynamic> toJson() => {
    't': timestamp.millisecondsSinceEpoch,
    'p': pressure.toStringAsFixed(3),
    'vx': velocityX.toStringAsFixed(3),
    'vy': velocityY.toStringAsFixed(3),
  };
}

/// Biometric session data
class BiometricSession {
  final String sessionId;
  final DateTime startTime;
  final List<MotionEvent> motionEvents;
  final List<TouchEvent> touchEvents;
  final Duration duration;

  BiometricSession({
    required this.sessionId,
    required this.startTime,
    required this.motionEvents,
    required this.touchEvents,
    required this.duration,
  });

  double get entropy {
    if (motionEvents.isEmpty) return 0.0;
    
    final magnitudes = motionEvents.map((e) => e.magnitude).toList();
    final Map<int, int> distribution = {};
    
    for (var mag in magnitudes) {
      int bucket = (mag * 10).round();
      distribution[bucket] = (distribution[bucket] ?? 0) + 1;
    }
    
    double entropy = 0.0;
    int total = magnitudes.length;
    
    distribution.forEach((_, count) {
      double probability = count / total;
      if (probability > 0) {
        entropy -= probability * (probability.toString().length / 10);
      }
    });
    
    return entropy;
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'start_time': startTime.toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'motion_count': motionEvents.length,
    'touch_count': touchEvents.length,
    'entropy': entropy.toStringAsFixed(4),
  };
}

/// Security states
enum SecurityState {
  LOCKED,
  VALIDATING,
  UNLOCKED,
  SOFT_LOCK,
  HARD_LOCK,
  ROOT_WARNING
}

/// Threat levels
enum ThreatLevel {
  SAFE,
  SUSPICIOUS,
  HIGH_RISK,
  CRITICAL
}

/// Validation attempt
class ValidationAttempt {
  final String attemptId;
  final DateTime timestamp;
  final List<int> inputCode;
  final BiometricSession? biometricData;
  final bool hasPhysicalMovement;

  ValidationAttempt({
    required this.attemptId,
    required this.timestamp,
    required this.inputCode,
    this.biometricData,
    required this.hasPhysicalMovement,
  });

  Map<String, dynamic> toJson() => {
    'attempt_id': attemptId,
    'timestamp': timestamp.toIso8601String(),
    'has_biometric': biometricData != null,
    'has_movement': hasPhysicalMovement,
    'biometric_summary': biometricData?.toJson(),
  };
}

/// Validation result
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

  factory ValidationResult.success({
    required double confidence,
    bool isPanicMode = false,
  }) {
    return ValidationResult(
      allowed: true,
      newState: SecurityState.UNLOCKED,
      threatLevel: ThreatLevel.SAFE,
      reason: isPanicMode ? 'PANIC_MODE_ACTIVATED' : 'VERIFIED',
      confidence: confidence,
      metadata: {'panic_mode': isPanicMode},
    );
  }

  factory ValidationResult.denied({
    required String reason,
    required ThreatLevel threatLevel,
    double confidence = 0.0,
  }) {
    return ValidationResult(
      allowed: false,
      newState: SecurityState.SOFT_LOCK,
      threatLevel: threatLevel,
      reason: reason,
      confidence: confidence,
    );
  }

  Map<String, dynamic> toJson() => {
    'allowed': allowed,
    'state': newState.name,
    'threat': threatLevel.name,
    'reason': reason,
    'confidence': confidence,
    'metadata': metadata,
  };
}
