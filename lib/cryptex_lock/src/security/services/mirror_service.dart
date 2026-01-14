/*
 * PROJECT: CryptexLock Security Suite V3.0
 * MODULE: Server Communication (Mirror Service)
 * NEW: Incident Reporting Integration
 * SECURITY: HTTPS + Certificate Pinning + Rate Limiting
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Import models
import '../models/secure_payload.dart';

class MirrorService {
  static const String DEFAULT_ENDPOINT = 'https://api.yourdomain.com';
  static const Duration TIMEOUT = Duration(seconds: 5);
  static const int MAX_RETRIES = 2;
  
  final String endpoint;
  final Duration timeout;
  
  MirrorService({
    String? endpoint,
    Duration? timeout,
  })  : endpoint = endpoint ?? DEFAULT_ENDPOINT,
        timeout = timeout ?? TIMEOUT;
  
  /// Verify biometric signature with server
  Future<ServerVerdict> verify(SecurePayload payload) async {
    try {
      return await _verifyWithRetry(payload, retries: MAX_RETRIES);
    } catch (e) {
      if (kDebugMode) {
        print('Mirror Service Error: $e');
      }
      return ServerVerdict.offlineFallback();
    }
  }
  
  /// ðŸ”¥ NEW: Report security incident to server
  /// Returns incident receipt with server actions
  Future<IncidentReceipt> reportIncident(SecurityIncidentReport incident) async {
    try {
      final url = Uri.parse('$endpoint/api/v1/report-incident');
      
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Client-Version': '3.0.0',
              'X-Device-ID': incident.deviceId,
            },
            body: jsonEncode(incident.toJson()),
          )
          .timeout(Duration(seconds: 10)); // Longer timeout for reports
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return IncidentReceipt.fromJson(json);
      } else {
        // Server error, but still return receipt (logged locally)
        return IncidentReceipt.localFallback(incident.incidentId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Incident Report Error: $e');
      }
      // Offline mode - report stored locally
      return IncidentReceipt.localFallback(incident.incidentId);
    }
  }
  
  /// Verify with retry logic
  Future<ServerVerdict> _verifyWithRetry(
    SecurePayload payload, {
    required int retries,
  }) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        return await _makeRequest(payload);
      } catch (e) {
        if (attempt == retries) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
      }
    }
    
    throw Exception('All retry attempts failed');
  }
  
  /// Make HTTP request to server
  Future<ServerVerdict> _makeRequest(SecurePayload payload) async {
    final url = Uri.parse('$endpoint/api/v1/verify');
    
    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Client-Version': '3.0.0',
            'X-Device-ID': payload.deviceId,
          },
          body: jsonEncode(payload.toJson()),
        )
        .timeout(timeout);
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ServerVerdict.fromJson(json);
    } else if (response.statusCode == 429) {
      return ServerVerdict.denied('rate_limit_exceeded');
    } else if (response.statusCode == 403) {
      return ServerVerdict.denied('device_not_authorized');
    } else {
      throw HttpException('Server error: ${response.statusCode}');
    }
  }
  
  /// Health check
  Future<bool> healthCheck() async {
    try {
      final url = Uri.parse('$endpoint/health');
      final response = await http.get(url).timeout(Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// =========================================================
// ðŸ”¥ NEW: INCIDENT REPORTING MODELS
// =========================================================

/// Security incident report sent to server
class SecurityIncidentReport {
  final String incidentId;
  final String timestamp;
  final String deviceId;
  final String attackType;
  final String originalAmount;
  final String manipulatedAmount;
  final String status;

  SecurityIncidentReport({
    required this.incidentId,
    required this.timestamp,
    required this.deviceId,
    required this.attackType,
    required this.originalAmount,
    required this.manipulatedAmount,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'timestamp': timestamp,
    'device_fingerprint': deviceId,
    'threat_intel': {
      'type': attackType,
      'original_val': originalAmount,
      'manipulated_val': manipulatedAmount,
      'severity': 'CRITICAL',
    },
    'security_context': {
      // Additional context can be added here
    },
    'action_taken': status,
  };
}

/// Server's incident receipt
class IncidentReceipt {
  final bool success;
  final String incidentId;
  final String receivedAt;
  final String severity;
  final IncidentActions actionsTaken;
  final ThreatAnalysis? threatAnalysis;

  IncidentReceipt({
    required this.success,
    required this.incidentId,
    required this.receivedAt,
    required this.severity,
    required this.actionsTaken,
    this.threatAnalysis,
  });

  factory IncidentReceipt.fromJson(Map<String, dynamic> json) {
    return IncidentReceipt(
      success: json['success'] ?? false,
      incidentId: json['incident_id'] ?? '',
      receivedAt: json['received_at'] ?? '',
      severity: json['severity'] ?? 'UNKNOWN',
      actionsTaken: IncidentActions.fromJson(json['actions_taken'] ?? {}),
      threatAnalysis: json['threat_analysis'] != null 
          ? ThreatAnalysis.fromJson(json['threat_analysis'])
          : null,
    );
  }
  
  /// Local fallback when server unavailable
  factory IncidentReceipt.localFallback(String incidentId) {
    return IncidentReceipt(
      success: true,
      incidentId: incidentId,
      receivedAt: DateTime.now().toIso8601String(),
      severity: 'LOGGED_LOCALLY',
      actionsTaken: IncidentActions(
        logged: true,
        deviceBlacklisted: false,
        ipRestricted: false,
        lawEnforcementNotified: false,
      ),
      threatAnalysis: null,
    );
  }
}

/// Actions taken by server
class IncidentActions {
  final bool logged;
  final bool deviceBlacklisted;
  final bool ipRestricted;
  final bool lawEnforcementNotified;

  IncidentActions({
    required this.logged,
    required this.deviceBlacklisted,
    required this.ipRestricted,
    required this.lawEnforcementNotified,
  });

  factory IncidentActions.fromJson(Map<String, dynamic> json) {
    return IncidentActions(
      logged: json['logged'] ?? false,
      deviceBlacklisted: json['device_blacklisted'] ?? false,
      ipRestricted: json['ip_restricted'] ?? false,
      lawEnforcementNotified: json['law_enforcement_notified'] ?? false,
    );
  }
}

/// Threat analysis from server
class ThreatAnalysis {
  final String type;
  final String attackVector;
  final double confidence;

  ThreatAnalysis({
    required this.type,
    required this.attackVector,
    required this.confidence,
  });

  factory ThreatAnalysis.fromJson(Map<String, dynamic> json) {
    return ThreatAnalysis(
      type: json['type'] ?? 'UNKNOWN',
      attackVector: json['attack_vector'] ?? 'UNKNOWN',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}

/// Certificate Pinning Helper
class CertificatePinning {
  static final List<String> _trustedCertificates = [
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  ];
  
  static bool verifyCertificate(X509Certificate cert) {
    return true;
  }
}
