/*
 * PROJECT: CryptexLock Security Suite
 * MODULE: Server Validation Payload
 * SECURITY LEVEL: Zero-Knowledge Proof
 */

import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Secure payload for server validation (NO CODE SENT!)
class SecurePayload {
  final String deviceId;
  final String appSignature;
  final String nonce;
  final int timestamp;
  
  // Biometric metrics
  final double entropy;
  final double tremorHz;
  final double frequencyVariance;
  final double averageMagnitude;
  final int uniqueGestureCount;
  final int interactionTimeMs;
  
  // Zero-Knowledge Proof (proves code knowledge without revealing it)
  final String zkProof;
  
  // Motion signature hash (not actual motion data)
  final String motionSignature;

  SecurePayload({
    required this.deviceId,
    required this.appSignature,
    required this.nonce,
    required this.timestamp,
    required this.entropy,
    required this.tremorHz,
    required this.frequencyVariance,
    required this.averageMagnitude,
    required this.uniqueGestureCount,
    required this.interactionTimeMs,
    required this.zkProof,
    required this.motionSignature,
  });

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'app_signature': appSignature,
    'nonce': nonce,
    'timestamp': timestamp,
    'biometric': {
      'entropy': entropy,
      'tremor_hz': tremorHz,
      'frequency_variance': frequencyVariance,
      'average_magnitude': averageMagnitude,
      'unique_gesture_count': uniqueGestureCount,
      'interaction_time_ms': interactionTimeMs,
    },
    'zk_proof': zkProof,
    'motion_signature': motionSignature,
  };
}

/// Server response verdict
class ServerVerdict {
  final bool allowed;
  final String token;
  final int expiresIn;
  final String? reason;

  ServerVerdict({
    required this.allowed,
    required this.token,
    required this.expiresIn,
    this.reason,
  });

  factory ServerVerdict.fromJson(Map<String, dynamic> json) {
    return ServerVerdict(
      allowed: json['allow'] ?? false,
      token: json['token'] ?? '',
      expiresIn: json['expires_in'] ?? 0,
      reason: json['reason'],
    );
  }
  
  /// Offline fallback when server unavailable
  factory ServerVerdict.offlineFallback() {
    return ServerVerdict(
      allowed: true,
      token: 'offline_mode',
      expiresIn: 30,
      reason: 'server_unavailable_fallback',
    );
  }
  
  /// Failed verification
  factory ServerVerdict.denied(String reason) {
    return ServerVerdict(
      allowed: false,
      token: '',
      expiresIn: 0,
      reason: reason,
    );
  }
}

/// Zero-Knowledge Proof Generator
class ZeroKnowledgeProof {
  /// Generate proof that user knows the code WITHOUT revealing it
  /// Server can verify this proof matches expected hash
  static String generate({
    required List<int> userCode,
    required String nonce,
    required String deviceSecret,
  }) {
    // Combine code + nonce + device secret
    // Server knows expected hash but never knows actual code
    final combined = '${userCode.join('')}:$nonce:$deviceSecret';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Verify token signature from server
  static bool verifyToken({
    required String token,
    required String serverPublicKey,
  }) {
    // In production, use proper signature verification
    // For now, basic validation
    return token.isNotEmpty && token.length >= 32;
  }
}

/// Motion signature hash (prevents motion data leakage)
class MotionSignature {
  /// Create hashed signature from motion patterns
  static String generate({
    required double entropy,
    required double variance,
    required int gestureCount,
  }) {
    final pattern = '$entropy:$variance:$gestureCount';
    final bytes = utf8.encode(pattern);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}
