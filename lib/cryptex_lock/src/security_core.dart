/*
 * PROJECT: Z-KINETIC SECURITY CORE V1.1
 * MODULE: Headless Security Orchestrator
 * DEPENDENCIES: ZERO Flutter, ZERO Platform Code
 * STATUS: SYNCED WITH MOTION_MODELS ✅
 */

import 'dart:math';
import 'dart:convert';
// import 'package:crypto/crypto.dart'; // ❌ Dibuang (Tak perlu)
import 'motion_models.dart';
import 'cla_models.dart';

/// Configuration for security core
class SecurityCoreConfig {
  final List<int> expectedCode;
  final Duration maxAttemptAge;
  final int maxFailedAttempts;
  final Duration lockoutDuration;
  
  // Biometric thresholds
  final double minConfidence;
  final double botThreshold;
  final double minEntropy;
  
  // Replay immunity
  final bool enforceReplayImmunity;
  final Duration nonceValidityWindow;
  
  // Attestation
  final AttestationProvider? attestationProvider;

  const SecurityCoreConfig({
    required this.expectedCode,
    this.maxAttemptAge = const Duration(seconds: 30),
    this.maxFailedAttempts = 3,
    this.lockoutDuration = const Duration(minutes: 1),
    this.minConfidence = 0.30,
    this.botThreshold = 0.40,
    this.minEntropy = 0.15,
    this.enforceReplayImmunity = true,
    this.nonceValidityWindow = const Duration(seconds: 60),
    this.attestationProvider,
  });

  /// Validate configuration integrity
  bool validate() {
    // Check for palindrome (panic mode requirement)
    final reversed = expectedCode.reversed.toList();
    if (_listEquals(expectedCode, reversed)) {
      throw ArgumentError('Palindromic codes not allowed for panic mode');
    }
    
    if (expectedCode.length < 3) {
      throw ArgumentError('Code must be at least 3 digits');
    }
    
    return true;
  }

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Abstract attestation provider (pluggable)
abstract class AttestationProvider {
  Future<AttestationResult> attest(ValidationAttempt attempt);
}

/// Attestation result
class AttestationResult {
  final bool verified;
  final String token;
  final DateTime expiresAt;
  final Map<String, dynamic> claims;

  AttestationResult({
    required this.verified,
    required this.token,
    required this.expiresAt,
    this.claims = const {},
  });
}

/// Replay immunity tracker
class ReplayTracker {
  final Map<String, DateTime> _usedNonces = {};
  final Duration _validityWindow;

  ReplayTracker(this._validityWindow);

  /// Check if nonce is valid and not replayed
  bool validateNonce(String nonce, DateTime timestamp) {
    // Clean expired nonces
    _cleanExpiredNonces();

    // Check if already used
    if (_usedNonces.containsKey(nonce)) {
      return false;
    }

    // Check timestamp freshness
    final age = DateTime.now().difference(timestamp);
    if (age > _validityWindow) {
      return false;
    }

    // Mark as used
    _usedNonces[nonce] = timestamp;
    return true;
  }

  void _cleanExpiredNonces() {
    final cutoff = DateTime.now().subtract(_validityWindow);
    _usedNonces.removeWhere((_, timestamp) => timestamp.isBefore(cutoff));
  }

  /// Generate secure nonce
  static String generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}

/// Core security engine (headless)
class SecurityCore {
  final SecurityCoreConfig config;
  final ReplayTracker _replayTracker;

  // State
  SecurityState _state = SecurityState.LOCKED;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  SecurityCore(this.config)
      : _replayTracker = ReplayTracker(config.nonceValidityWindow) {
    config.validate();
  }

  SecurityState get state => _state;
  int get failedAttempts => _failedAttempts;

  /// Main validation entry point
  Future<ValidationResult> validate(ValidationAttempt attempt) async {
    // 1. Check lockout
    if (_isLockedOut()) {
      return ValidationResult.denied(
        reason: 'SYSTEM_LOCKED',
        threatLevel: ThreatLevel.HIGH_RISK,
        confidence: 0.0,
      );
    }

    // 2. Replay immunity check
    if (config.enforceReplayImmunity) {
      final replayResult = _checkReplay(attempt);
      if (!replayResult.allowed) {
        return replayResult;
      }
    }

    // 3. Attestation check (if configured)
    if (config.attestationProvider != null) {
      final attestationResult = await config.attestationProvider!.attest(attempt);
      if (!attestationResult.verified) {
        return ValidationResult.denied(
          reason: 'ATTESTATION_FAILED',
          threatLevel: ThreatLevel.CRITICAL,
          confidence: 0.0,
        );
      }
    }

    // 4. Code validation
    final codeResult = _validateCode(attempt.inputCode);
    if (codeResult == null) {
      // Wrong code
      return _handleFailure();
    }

    // 5. Biometric validation
    if (attempt.biometricData != null) {
      final bioResult = _validateBiometric(attempt.biometricData!);
      if (!bioResult.allowed) {
        return bioResult;
      }
    } else if (!attempt.hasPhysicalMovement) {
      // No biometric + no movement = suspicious
      return ValidationResult.denied(
        reason: 'NO_BIOMETRIC_DATA',
        threatLevel: ThreatLevel.SUSPICIOUS,
        confidence: 0.0,
      );
    }

    // 6. Success handling
    return _handleSuccess(
      isPanicMode: codeResult == CodeMatch.panic,
      confidence: attempt.biometricData?.entropy ?? 0.7,
    );
  }

  /// Check for replay attacks
  ValidationResult _checkReplay(ValidationAttempt attempt) {
    final nonce = attempt.attemptId;
    final timestamp = attempt.timestamp;

    if (!_replayTracker.validateNonce(nonce, timestamp)) {
      return ValidationResult.denied(
        reason: 'REPLAY_DETECTED',
        threatLevel: ThreatLevel.CRITICAL,
        confidence: 0.0,
      );
    }

    // Temporary success result just to pass the check (not final result)
    return ValidationResult(
      allowed: true,
      newState: _state,
      threatLevel: ThreatLevel.SAFE,
      reason: 'REPLAY_CHECK_PASSED',
      confidence: 1.0,
    );
  }

  /// Validate code (normal vs panic)
  CodeMatch? _validateCode(List<int> inputCode) {
    // Normal code
    if (_listEquals(inputCode, config.expectedCode)) {
      return CodeMatch.normal;
    }

    // Panic code (reversed)
    final reversed = config.expectedCode.reversed.toList();
    if (_listEquals(inputCode, reversed)) {
      return CodeMatch.panic;
    }

    return null;
  }

  /// Validate biometric data
  // ✅ PEMBETULAN: Tukar BiometricSession -> BiometricData
  ValidationResult _validateBiometric(BiometricData data) {
    final entropy = data.entropy;
    final motionCount = data.motionEvents.length;
    final touchCount = data.touchEvents.length;

    // Bot detection: too perfect or too fast
    if (entropy < config.minEntropy && touchCount < 3) {
      return ValidationResult.denied(
        reason: 'BOT_DETECTED',
        threatLevel: ThreatLevel.HIGH_RISK,
        confidence: 0.0,
      );
    }

    // Calculate confidence score
    final confidence = _calculateConfidence(entropy, motionCount, touchCount);

    if (confidence < config.minConfidence) {
      return ValidationResult.denied(
        reason: 'LOW_CONFIDENCE',
        threatLevel: ThreatLevel.SUSPICIOUS,
        confidence: confidence,
      );
    }

    return ValidationResult(
      allowed: true,
      newState: _state,
      threatLevel: ThreatLevel.SAFE,
      reason: 'BIOMETRIC_VERIFIED',
      confidence: confidence,
    );
  }

  double _calculateConfidence(double entropy, int motionCount, int touchCount) {
    // Weighted scoring
    const entropyWeight = 0.4;
    const motionWeight = 0.3;
    const touchWeight = 0.3;

    final entropyScore = (entropy / 4.0).clamp(0.0, 1.0);
    final motionScore = (motionCount / 20.0).clamp(0.0, 1.0);
    final touchScore = (touchCount / 10.0).clamp(0.0, 1.0);

    return (entropyScore * entropyWeight +
            motionScore * motionWeight +
            touchScore * touchWeight)
        .clamp(0.0, 1.0);
  }

  ValidationResult _handleSuccess({
    required bool isPanicMode,
    required double confidence,
  }) {
    _state = SecurityState.UNLOCKED;
    _failedAttempts = 0;
    _lockoutUntil = null;

    return ValidationResult.success(
      confidence: confidence,
      isPanicMode: isPanicMode,
    );
  }

  ValidationResult _handleFailure() {
    _failedAttempts++;

    if (_failedAttempts >= config.maxFailedAttempts) {
      _state = SecurityState.HARD_LOCK;
      _lockoutUntil = DateTime.now().add(config.lockoutDuration);

      return ValidationResult.denied(
        reason: 'MAX_ATTEMPTS_EXCEEDED',
        threatLevel: ThreatLevel.HIGH_RISK,
        confidence: 0.0,
      );
    }

    _state = SecurityState.SOFT_LOCK;

    return ValidationResult.denied(
      reason: 'INVALID_CODE',
      threatLevel: ThreatLevel.SUSPICIOUS,
      confidence: 0.0,
    );
  }

  bool _isLockedOut() {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isAfter(_lockoutUntil!)) {
      _lockoutUntil = null;
      _state = SecurityState.LOCKED;
      return false;
    }
    return true;
  }

  int get remainingLockoutSeconds {
    if (_lockoutUntil == null) return 0;
    final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void reset() {
    _state = SecurityState.LOCKED;
    _failedAttempts = 0;
    _lockoutUntil = null;
  }
}

enum CodeMatch { normal, panic }
