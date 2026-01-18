// LOKASI: lib/cryptex_lock/src/motion_models.dart

import 'dart:math';

enum ThreatLevel { SAFE, SUSPICIOUS, HIGH_RISK, CRITICAL }

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

class TouchEvent {
  final DateTime timestamp;
  final double pressure;
  final double x; 
  final double y; 

  TouchEvent({
    required this.timestamp,
    this.pressure = 0.5,
    this.x = 0.0,
    this.y = 0.0,
  });

  Map<String, dynamic> toJson() => {
    't': timestamp.millisecondsSinceEpoch,
    'p': pressure.toStringAsFixed(3),
    'x': x.toStringAsFixed(1),
    'y': y.toStringAsFixed(1),
  };
}

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
      double p = count / total;
      if (p > 0) entropy -= p * (log(p) / log(2)); 
    });
    return (entropy / 3.0).clamp(0.0, 1.0);
  }

  double get tremorScore {
    if (motionEvents.length < 5) return 0.0;
    double sum = 0.0;
    double sumSq = 0.0;
    for (var e in motionEvents) {
      sum += e.magnitude;
      sumSq += (e.magnitude * e.magnitude);
    }
    double mean = sum / motionEvents.length;
    double variance = (sumSq / motionEvents.length) - (mean * mean);
    return sqrt(variance.abs()).clamp(0.0, 1.0);
  }

  double get typingSpeedScore {
    if (touchEvents.length < 2) return 0.5;
    double totalGap = 0.0;
    for (int i = 0; i < touchEvents.length - 1; i++) {
      totalGap += touchEvents[i+1].timestamp.difference(touchEvents[i].timestamp).inMilliseconds;
    }
    double avgGap = totalGap / (touchEvents.length - 1);
    return (avgGap / 500.0).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'stats': {'entropy': entropy, 'tremor': tremorScore},
  };
}

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
    'code_length': inputCode.length,
    'biometric_data': biometricData?.toJson(),
  };
}

class ValidationResult {
  final bool allowed;
  final String reason;
  final double confidence;
  final ThreatLevel threatLevel; // WAJIB ADA
  final Map<String, dynamic> metadata;
  final dynamic newState;

  ValidationResult({
    required this.allowed,
    required this.reason,
    required this.confidence,
    required this.threatLevel,
    this.metadata = const {},
    this.newState,
  });
}
