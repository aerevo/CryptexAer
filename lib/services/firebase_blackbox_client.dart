// 🛡️ Z-KINETIC V3.2 (FIREBASE BLACK BOX CLIENT)
// Location: lib/services/firebase_blackbox_client.dart
// Status: REPAIR FIXED ✅ | PRODUCTION READY
// Features: Debug Logs, Emulator Standby, Incident Reporting

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../cryptex_lock/src/motion_models.dart';

// ============================================
// VERDICT MODEL
// ============================================
class BlackBoxVerdict {
  final bool allowed;
  final String reason;
  final Map<String, dynamic>? rawData;

  BlackBoxVerdict({
    required this.allowed,
    required this.reason,
    this.rawData,
  });

  factory BlackBoxVerdict.fromJson(dynamic json) {
    if (json == null || json is! Map) {
      return BlackBoxVerdict.offlineFallback();
    }
    return BlackBoxVerdict(
      allowed: json['allowed'] == true,
      reason: json['reason']?.toString() ?? 'UNKNOWN_RESPONSE',
      rawData: Map<String, dynamic>.from(json),
    );
  }

  factory BlackBoxVerdict.denied(String reason) {
    return BlackBoxVerdict(allowed: false, reason: reason);
  }

  factory BlackBoxVerdict.offlineFallback() {
    return BlackBoxVerdict(
      allowed: false, 
      reason: 'SYSTEM_OFFLINE'
    );
  }

  @override
  String toString() => 'Verdict(allowed: $allowed, reason: $reason)';
}

// ============================================
// INCIDENT RECEIPT MODEL
// ============================================
class IncidentReceipt {
  final String incidentId;
  final DateTime timestamp;
  final String status;

  IncidentReceipt({
    required this.incidentId,
    required this.timestamp,
    required this.status,
  });

  factory IncidentReceipt.fromJson(Map<String, dynamic> json) {
    return IncidentReceipt(
      incidentId: json['incidentId'] ?? 'UNKNOWN',
      timestamp: DateTime.now(),
      status: json['status'] ?? 'PROCESSED',
    );
  }
}

// ============================================
// FIREBASE CLIENT SERVICE
// ============================================
class FirebaseBlackBoxClient {
  late final FirebaseFunctions _functions;

  FirebaseBlackBoxClient() {
    // 🇸🇬 Region: Singapore (asia-southeast1)
    _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    
    // 🛠️ EMULATOR PLACEHOLDER
    // if (kDebugMode) {
    //   _functions.useFunctionsEmulator('10.0.2.2', 5001);
    // }
  }

  /// Menghantar data telemetri ke Cloud untuk dianalisis AI
  /// ✅ FIXED: Parameter 'biometric' diselaraskan dengan Controller
  Future<BlackBoxVerdict> analyze({
    required String deviceId,
    required BiometricSession biometric,
    required String sessionId,
    required String nonce,
    required int timestamp,
  }) async {
    
    if (kDebugMode) {
      print('🔥 [DEBUG] Calling Firebase Function (analyzeBlackBox)...');
      print('   Device ID: $deviceId');
      print('   Session ID: $sessionId');
      print('   Nonce: $nonce');
    }
    
    try {
      final result = await _functions
          .httpsCallable('analyzeBlackBox')
          .call({
            'deviceId': deviceId,
            'biometric': _serializeBiometric(biometric),
            'sessionId': sessionId,
            'nonce': nonce,
            'timestamp': timestamp,
          })
          .timeout(const Duration(seconds: 15));
      
      if (kDebugMode) {
        print('✅ [DEBUG] Response Received: ${result.data}');
      }
      
      return BlackBoxVerdict.fromJson(result.data);
      
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('❌ [DEBUG] Firebase Function Error:');
        print('   Code: ${e.code}');
        print('   Message: ${e.message}');
      }
      
      if (e.code == 'unauthenticated') {
        return BlackBoxVerdict.denied('AUTH_REQUIRED');
      }
      return BlackBoxVerdict.offlineFallback();
      
    } catch (e) {
      if (kDebugMode) {
        print('💥 [DEBUG] Unknown Connection Error: $e');
      }
      return BlackBoxVerdict.offlineFallback();
    }
  }

  /// Melaporkan insiden keselamatan ke Firebase Cloud
  Future<IncidentReceipt> reportIncident({
    required String deviceId,
    required String incidentId,
    required Map<String, dynamic> threatIntel,
    Map<String, dynamic>? securityContext,
  }) async {
    try {
      if (kDebugMode) print('🛡️ [DEBUG] Reporting Incident: $incidentId');
      
      final result = await _functions
          .httpsCallable('reportIncident')
          .call({
            'incidentId': incidentId,
            'deviceId': deviceId,
            'threatIntel': threatIntel,
            'securityContext': securityContext ?? {},
          });
          
      return IncidentReceipt.fromJson(Map<String, dynamic>.from(result.data));
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to report incident: $e');
      rethrow;
    }
  }

  /// Menukar objek BiometricSession kepada struktur JSON yang faham oleh Firebase
  Map<String, dynamic> _serializeBiometric(BiometricSession session) {
    return {
      'motion_events': session.motionEvents.map((e) => {
        'm': e.magnitude,
        't': e.timestamp.millisecondsSinceEpoch,
        'dx': e.deltaX,
        'dy': e.deltaY,
        'dz': e.deltaZ,
      }).toList(),
      'touch_events': session.touchEvents.map((e) => {
        't': e.timestamp.millisecondsSinceEpoch,
        'p': e.pressure,
        'vx': e.velocityX,
        'vy': e.velocityY,
      }).toList(),
      'duration_ms': session.duration.inMilliseconds,
      'session_id': session.sessionId,
    };
  }
}
