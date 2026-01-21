// File: lib/src/services/firebase_blackbox_client.dart
// 🛡️ FIREBASE BLACK BOX CLIENT
// Status: DEBUG MODE ENABLED 🐞

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

// ✅ MODEL: BlackBoxVerdict (Diletakkan sekali untuk elak error import)
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

/// Client untuk berhubung dengan Google Cloud Functions
class FirebaseBlackBoxClient {
  // Pastikan region 'asia-southeast1' (Singapore)
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1'
  );

  /// Menghantar data telemetri ke Cloud untuk dianalisis AI
  Future<BlackBoxVerdict> analyze({
    required String deviceId,
    required String sessionId,
    required Map<String, dynamic> telemetryData,
  }) async {
    
    // 🔥 [DEBUG] LOGS: Memantau status sambungan
    if (kDebugMode) {
      print('🔥 [DEBUG] Calling Firebase Function (analyzeBlackBox)...');
      print('   Device ID: $deviceId');
      print('   Session ID: $sessionId');
    }
    
    try {
      final result = await _functions
          .httpsCallable('analyzeBlackBox')
          .call({
            'deviceId': deviceId,
            'sessionId': sessionId,
            'telemetry': telemetryData,
            'timestamp': DateTime.now().toIso8601String(),
          })
          .timeout(const Duration(seconds: 10));
      
      if (kDebugMode) {
        print('✅ [DEBUG] Response: ${result.data}');
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
      // Fail-Secure: Tolak akses jika ragu-ragu
      return BlackBoxVerdict.offlineFallback();
      
    } catch (e) {
      if (kDebugMode) {
        print('💥 [DEBUG] Unknown Connection Error: $e');
      }
      return BlackBoxVerdict.offlineFallback();
    }
  }
}
