/*
 * PROJECT: CryptexLock Security Suite
 * MODE: ACCELEROMETER FIRST (Classic)
 * INTEGRATION: Server Validation Ready
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
  
  // Server validation config
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
  
  bool get hasServerValidation => 
      securityConfig != null && 
      securityConfig!.enableServerValidation;
}

/// Structure for detailed motion analysis
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
