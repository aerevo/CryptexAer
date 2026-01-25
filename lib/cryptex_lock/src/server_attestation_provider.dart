// lib/cryptex_lock/src/server_attestation_provider.dart (FIXED ✅)

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'security_core.dart';
import 'motion_models.dart';

// Device fingerprint helper (embedded)
class _DeviceFingerprint {
  static String _cachedDeviceId = '';
  static String _cachedSecret = '';

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId.isNotEmpty) return _cachedDeviceId;

    _cachedDeviceId = 'DEVICE_${DateTime.now().millisecondsSinceEpoch}';
    return _cachedDeviceId;
  }

  static Future<String> getDeviceSecret() async {
    if (_cachedSecret.isNotEmpty) return _cachedSecret;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final input = 'SECRET_$timestamp';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);

    _cachedSecret = digest.toString();
    return _cachedSecret;
  }
}

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

class ServerAttestationProvider implements AttestationProvider {
  final ServerAttestationConfig config;

  DateTime? _lastRequest;
  int _requestCount = 0;
  static const int _maxRequestsPerMinute = 10;

  ServerAttestationProvider(this.config);

  @override
  Future<AttestationResult> attest(ValidationAttempt attempt) async {
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

      return AttestationResult(
        verified: false,
        token: '',
        expiresAt: DateTime.now(),
        claims: {'error': e.toString()},
      );
    }
  }

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

        await Future.delayed(Duration(milliseconds: 500 * retries));
      }
    }

    throw Exception('Max retries exceeded');
  }

  Future<AttestationResult> _makeAttestationRequest(
    ValidationAttempt attempt
  ) async {
    _trackRequest();

    final payload = await _buildAttestationPayload(attempt);

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

    if (response.statusCode == 200) {
      return _parseAttestationResponse(response.body);
    } else if (response.statusCode == 429) {
      throw RateLimitException('Server rate limit exceeded');
    } else if (response.statusCode == 403) {
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

  Future<Map<String, dynamic>> _buildAttestationPayload(
    ValidationAttempt attempt
  ) async {
    final deviceId = await _DeviceFingerprint.getDeviceId();
    final deviceSecret = await _DeviceFingerprint.getDeviceSecret();

    final zkProof = _generateZKProof(
      attempt.inputCode,
      attempt.attemptId,
      deviceSecret,
    );

    // ✅ FIXED: Cek type sebelum summarize
    final bioSummary = attempt.biometricData != null
      ? _summarizeBiometricData(attempt.biometricData!)
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

  String _generateZKProof(
    List<int> code,
    String nonce,
    String deviceSecret,
  ) {
    final combined = '${code.join('')}:$nonce:$deviceSecret';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ✅ FIXED: Terima BiometricData (bukan BiometricSession)
  Map<String, dynamic> _summarizeBiometricData(BiometricData data) {
    return {
      'entropy': data.entropy.toStringAsFixed(4),
      'motion_count': data.motionEvents.length,
      'touch_count': data.touchEvents.length,
    };
  }

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

  Future<AttestationResult> _useFallback(ValidationAttempt attempt) async {
    if (config.fallbackProvider != null) {
      return await config.fallbackProvider!.attest(attempt);
    }

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
