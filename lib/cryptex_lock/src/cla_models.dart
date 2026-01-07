/*
 * PROJECT: CryptexLock Security Suite
 * CONFIG: QUICK COOLDOWN (5 Seconds)
 */

import 'security/config/security_config.dart';

enum SecurityState {
  LOCKED,           
  VALIDATING,       
  UNLOCKED,         
  SOFT_LOCK,        
  HARD_LOCK,        
  BOT_SIMULATION,   
  ROOT_WARNING,     
  COMPROMISED       
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
  
  final double botDetectionSensitivity;
  final SecurityConfig? securityConfig;

  const ClaConfig({
    required this.secret,
    required this.minSolveTime,
    required this.minShake,
    // 🔥 FIX 1: Default Cooldown dipendekkan ke 5 saat (Dulu lama)
    this.jamCooldown = const Duration(seconds: 5), 
    this.softLockCooldown = const Duration(seconds: 2), // Soft lock pun laju
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
