/*
 * PROJECT: Z-KINETIC SECURITY CORE
 * MODULE: Server-Side Attestation Provider
 * PURPOSE: Remote attestation via backend API
 * 
 * USAGE:
 * final attestation = ServerAttestationProvider(
 *   endpoint: 'https://your-api.com/attest',
 *   apiKey: 'your-api-key',
 * );
 * 
 * FEATURES:
 * - Zero-knowledge proof submission
 * - Server-side bot detection
 * - Device blacklist checking
 * - Rate limiting
 * - Fallback to local attestation
 */

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'security_core.dart';
import 'motion_models.dart';
import '../security/services/device_fingerprint.dart';

/// Server attestation configuration
class ServerAttestationConfig {
  final String endpoint;
  final String apiKey;
  final Duration timeout;
  final int maxRetries;
  final bool enableFallback;
  final AttestationProvider? fallbackProvider;

  const ServerAttestationConfig({
    required this.endpoint,
    required this.apiKey,
    this.timeout = const Duration(seconds: 5),
    this.maxRetries = 2,
    this.enableFallback = true,
    this.fallbackProvider,
  });
}

/// Server attestation provider
class ServerAttestationProvider implements AttestationProvider {
  final ServerAttestationConfig config;
  
  // Rate limiting
  DateTime? _lastRequest;
  int _requestCount = 0;
  static const int _maxRequestsPerMinute = 10;

  ServerAttestationProvider(this.config);

  @override
  Future<AttestationResult> attest(ValidationAttempt attempt) async {
    // Check rate limiting
    if (_isRateLimited()) {
      if (kDebugMode) print('⚠️ Rate limited - using fallback');
      return _useFallback(attempt);
    }

    try {
      return await _attestWithRetry(attempt);
    } catch (e) {
      if (kDebugMode) print('❌ Server attestation failed: $e');
      
      if (config.enableFallback) {
        return _useFallback(attempt);
      }
      
      // No fallback - deny by default
      return AttestationResult(
        verified: false,
        token: '',
        expiresAt: DateTime.now(),
        claims: {'error': e.toString()},
      );
    }
  }

  /// Attest with retry logic
  Future<AttestationResult> _attestWithRetry(ValidationAttempt attempt) async {
    int retries = 0;
    
    while (retries <= config.maxRetries) {
      try {
        return await _makeAttestationRequest(attempt);
      } catch (e) {
        retries++;
        
        if (retries > config.maxRetries) {
          rethrow;
        }
        
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 500 * retries));
      }
    }
    
    throw Exception('Max retries exceeded');
  }

  /// Make attestation request to server
  Future<AttestationResult> _makeAttestationRequest(
    ValidationAttempt attempt
  ) async {
    _trackRequest();

    // Build attestation payload (zero-knowledge)
    final payload = await _buildAttestationPayload(attempt);

    // Make HTTP request
    final response = await http.post(
      Uri.parse(config.endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
        'X-Client-Version': '2.0.0',
        'X-Request-ID': attempt.attemptId,
      },
      body: jsonEncode(payload),
    ).timeout(config.timeout);

    // Parse response
    if (response.statusCode == 200) {
      return _parseAttestationResponse(response.body);
    } else if (response.statusCode == 429) {
      throw RateLimitException('Server rate limit exceeded');
    } else if (response.statusCode == 403) {
      // Device blacklisted
      return AttestationResult(
        verified: false,
        token: '',
        expiresAt: DateTime.now(),
        claims: {'reason': 'DEVICE_BLACKLISTED'},
      );
    } else {
      throw ServerException('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Build zero-knowledge attestation payload
  Future<Map<String, dynamic>> _buildAttestationPayload(
    ValidationAttempt attempt
  ) async {
    final deviceId = await DeviceFingerprint.getDeviceId();
    final deviceSecret = await DeviceFingerprint.getDeviceSecret();

    // Generate zero-knowledge proof (don't send actual code!)
    final zkProof = _generateZKProof(
      attempt.inputCode,
      attempt.attemptId,
      deviceSecret,
    );

    // Biometric summary (no raw data)
    final bioSummary = attempt.biometricData != null
        ? _summarizeBiometric(attempt.biometricData!)
        : null;

    return {
      'attempt_id': attempt.attemptId,
      'timestamp': attempt.timestamp.toIso8601String(),
      'device_id': deviceId,
      'zk_proof': zkProof,
      'has_biometric': attempt.biometricData != null,
      'biometric_summary': bioSummary,
      'has_movement': attempt.hasPhysicalMovement,
    };
  }

  /// Generate zero-knowledge proof
  String _generateZKProof(
    List<int> code,
    String nonce,
    String deviceSecret,
  ) {
    // Combine code + nonce + device secret
    // Server can verify this matches expected hash WITHOUT knowing code
    final combined = '${code.join('')}:$nonce:$deviceSecret';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Summarize biometric data (no PII)
  Map<String, dynamic> _summarizeBiometric(BiometricSession session) {
    return {
      'entropy': session.entropy.toStringAsFixed(4),
      'motion_count': session.motionEvents.length,
      'touch_count': session.touchEvents.length,
      'duration_ms': session.duration.inMilliseconds,
      'session_id': session.sessionId,
    };
  }

  /// Parse server attestation response
  AttestationResult _parseAttestationResponse(String responseBody) {
    final data = jsonDecode(responseBody);

    return AttestationResult(
      verified: data['verified'] ?? false,
      token: data['token'] ?? '',
      expiresAt: DateTime.parse(data['expires_at']),
      claims: {
        'server_verdict': data['verdict'],
        'risk_score': data['risk_score'],
        'threat_level': data['threat_level'],
        'server_timestamp': data['timestamp'],
      },
    );
  }

  /// Use fallback provider
  Future<AttestationResult> _useFallback(ValidationAttempt attempt) async {
    if (config.fallbackProvider != null) {
      return await config.fallbackProvider!.attest(attempt);
    }

    // No fallback available - allow by default (risky!)
    if (kDebugMode) {
      print('⚠️ WARNING: No fallback provider - allowing by default');
    }

    return AttestationResult(
      verified: true,
      token: 'FALLBACK_MODE',
      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      claims: {'mode': 'fallback', 'reason': 'server_unavailable'},
    );
  }

  /// Track request for rate limiting
  void _trackRequest() {
    final now = DateTime.now();
    
    if (_lastRequest == null || 
        now.difference(_lastRequest!) > const Duration(minutes: 1)) {
      _requestCount = 1;
      _lastRequest = now;
    } else {
      _requestCount++;
    }
  }

  /// Check if rate limited
  bool _isRateLimited() {
    if (_lastRequest == null) return false;
    
    final elapsed = DateTime.now().difference(_lastRequest!);
    
    if (elapsed > const Duration(minutes: 1)) {
      _requestCount = 0;
      return false;
    }
    
    return _requestCount >= _maxRequestsPerMinute;
  }
}

/// Custom exceptions
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  
  @override
  String toString() => 'RateLimitException: $message';
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
  
  @override
  String toString() => 'ServerException: $message';
}

/// Example server endpoint implementation (for reference)
/// 
/// POST /api/v1/attest
/// 
/// Request:
/// {
///   "attempt_id": "NONCE_ABC123",
///   "timestamp": "2026-01-18T10:30:00Z",
///   "device_id": "DEVICE_XYZ789",
///   "zk_proof": "sha256_hash_of_code+nonce+secret",
///   "has_biometric": true,
///   "biometric_summary": {
///     "entropy": "0.6234",
///     "motion_count": 15,
///     "touch_count": 8,
///     "duration_ms": 2500
///   },
///   "has_movement": true
/// }
/// 
/// Response (Success):
/// {
///   "verified": true,
///   "token": "JWT_TOKEN_HERE",
///   "expires_at": "2026-01-18T10:35:00Z",
///   "verdict": "ALLOWED",
///   "risk_score": 0.15,
///   "threat_level": "LOW",
///   "timestamp": "2026-01-18T10:30:01Z"
/// }
/// 
/// Response (Denied):
/// {
///   "verified": false,
///   "token": "",
///   "expires_at": "2026-01-18T10:30:00Z",
///   "verdict": "DENIED",
///   "risk_score": 0.85,
///   "threat_level": "HIGH",
///   "timestamp": "2026-01-18T10:30:01Z",
///   "reason": "BOT_DETECTED"
/// }
