// FILE: lib/cryptex_lock/src/motion_models.dart
// STATUS: HYBRID BRIDGE (Supports V1 & V3) ✅

import 'dart:math';
import 'dart:ui';
import 'cla_models.dart'; // Pastikan ini wujud

// ==========================================
// 1. MODERN TYPES (Untuk Controller V3)
// ==========================================

class TouchData {
  final DateTime timestamp;
  final double pressure;
  final Offset position;

  TouchData({
    required this.timestamp,
    required this.pressure,
    required this.position,
  });
}

class MotionData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  MotionData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  // Compatibility getter for Legacy engines
  double get magnitude => sqrt(x*x + y*y + z*z);
}

// ==========================================
// 2. LEGACY COMPATIBILITY (Untuk Security Core Lama)
// ==========================================

// Alias: Kalau ada fail minta 'MotionEvent', bagi dia 'MotionData'
typedef MotionEvent = MotionData; 

class ValidationAttempt {
  final List<int> input;
  final DateTime timestamp;
  
  ValidationAttempt(this.input, {DateTime? timestamp}) 
      : timestamp = timestamp ?? DateTime.now();
}

class BiometricSession {
  final String sessionId;
  final List<MotionData> motionEvents;
  final List<TouchData> touchEvents;
  final Duration duration;
  final double entropy;

  BiometricSession({
    required this.sessionId,
    required this.motionEvents,
    required this.touchEvents,
    required this.duration,
    required this.entropy,
  });
}

// ==========================================
// 3. HYBRID RESULT (Faham Semua Bahasa)
// ==========================================

class ValidationResult {
  final bool isValid;
  final bool isPanic;
  final String? message;
  
  // Legacy fields
  final SecurityState newState;
  final dynamic threatLevel;
  final double confidence;

  ValidationResult({
    required this.isValid,
    this.isPanic = false,
    this.message,
    this.newState = SecurityState.LOCKED,
    this.threatLevel,
    this.confidence = 0.0,
  });

  // Getter supaya kod lama yang cari '.allowed' tak crash
  bool get allowed => isValid;

  // Factory untuk kod lama
  factory ValidationResult.denied({
    required String reason, 
    dynamic threatLevel,
    double confidence = 0.0
  }) {
    return ValidationResult(
      isValid: false,
      message: reason,
      newState: SecurityState.LOCKED,
      confidence: confidence,
    );
  }

  factory ValidationResult.success({
    double confidence = 1.0, 
    bool isPanicMode = false
  }) {
    return ValidationResult(
      isValid: true,
      isPanic: isPanicMode,
      newState: SecurityState.UNLOCKED,
      confidence: confidence,
    );
  }
}
