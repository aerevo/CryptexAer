// lib/cryptex_lock/src/cla_models.dart

import 'security_core.dart';

enum SecurityState {
  LOCKED,
  VALIDATING,
  UNLOCKED,
  SOFT_LOCK,
  HARD_LOCK,
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
    this.deltaX = 0,
    this.deltaY = 0,
    this.deltaZ = 0,
  });
}

class TouchEvent {
  final DateTime timestamp;
  final double pressure;
  final double velocityX;
  final double velocityY;

  TouchEvent({
    required this.timestamp,
    required this.pressure,
    required this.velocityX,
    required this.velocityY,
  });
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
  });
}
