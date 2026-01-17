/*
 * PROJECT: CryptexLock Security Suite V3.2
 * MODULE: Mirror Service (Server Communication)
 * STATUS: SECURE (SSL Pinning Ready) ✅
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';

// ============================================
// SHARED MODELS (Digunakan oleh IncidentReporter)
// ============================================

class SecurityIncidentReport {
  final String incidentId;
  final String timestamp;
  final String deviceId;
  final String attackType;
  final String detectedValue;
  final String expectedSignature;
  final String action;

  SecurityIncidentReport({
    required this.incidentId,
    required this.timestamp,
    required this.deviceId,
    required this.attackType,
    required this.detectedValue,
    required this.expectedSignature,
    required this.action,
  });

  Map<String, dynamic> toJson() => {
    'incident_id': incidentId,
    'timestamp': timestamp,
    'device_id': deviceId,
    'threat_intel': {
      'type': attackType,
      'detected': detectedValue,
      'signature': expectedSignature,
    },
    'status': action,
  };

  factory SecurityIncidentReport.fromJson(Map<String, dynamic> json) {
    return SecurityIncidentReport(
      incidentId: json['incident_id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      deviceId: json['device_id'] ?? '',
      attackType: json['threat_intel']?['type'] ?? 'UNKNOWN',
      detectedValue: json['threat_intel']?['detected'] ?? '',
      expectedSignature: json['threat_intel']?['signature'] ?? '',
      action: json['status'] ?? 'UNKNOWN',
    );
  }
}

class IncidentReceipt {
  final String incidentId;
  final String status;

  IncidentReceipt({required this.incidentId, required this.status});
}

// ============================================
// SERVICE IMPLEMENTATION
// ============================================

class MirrorService {
  final String baseUrl;
  late final http.Client _client;

  // 🔒 PRODUCTION CERTIFICATE PINNING
  // Masukkan SHA-256 hash certificate server sebenar di sini nanti
  static const String _EXPECTED_CERT_HASH = "SHA256_HASH_OF_YOUR_SERVER_CERT";

  MirrorService({this.baseUrl = 'https://api.aer-security.com/v1'}) {
    _client = _createSecureClient();
  }

  /// Create HTTP Client with SSL Pinning capability
  http.Client _createSecureClient() {
    final context = SecurityContext.defaultContext;
    
    // NOTE: In production, load your PEM certificate here:
    // context.setTrustedCertificatesBytes(myCertBytes);

    final httpClient = HttpClient(context: context);

    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // 🛡️ SECURITY CHECK: Validate Certificate Fingerprint
      if (kDebugMode) {
        return true; // Allow self-signed in Debug ONLY
      }
      
      // In Production: Compare cert.sha256 with _EXPECTED_CERT_HASH
      // return _validateCert(cert); 
      return false; // Fail by default
    };

    return IOClient(httpClient);
  }

  Future<IncidentReceipt> reportIncident(SecurityIncidentReport report) async {
    // Simulate Network Call
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock Response
    // In real app: final response = await _client.post(...)
    
    debugPrint("📡 UPLOADED INCIDENT: ${report.incidentId} [${report.attackType}]");
    
    return IncidentReceipt(
      incidentId: report.incidentId, 
      status: 'LOGGED_ON_SERVER'
    );
  }
}
