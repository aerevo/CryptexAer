// 🔥 FIREBASE BLACK BOX CLIENT
// Location: lib/services/firebase_blackbox_client.dart
// Status: PRODUCTION READY

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/blackbox_verdict.dart';
import '../cryptex_lock/src/motion_models.dart';

class FirebaseBlackBoxClient {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  Future<BlackBoxVerdict> analyze({
    required String deviceId,
    required BiometricSession biometric,
    required String sessionId,
    required String nonce,
    required int timestamp,
  }) async {
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
          .timeout(const Duration(seconds: 10));

      return BlackBoxVerdict.fromJson(result.data);

    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) print('🔥 Firebase error: ${e.code}');
      if (e.code == 'unauthenticated') {
        return BlackBoxVerdict.denied('AUTH_REQUIRED');
      }
      return BlackBoxVerdict.offlineFallback();
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return BlackBoxVerdict.offlineFallback();
    }
  }

  Future<IncidentReceipt> reportIncident({
    required String deviceId,
    required String incidentId,
    required Map<String, dynamic> threatIntel,
    Map<String, dynamic>? securityContext,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('reportIncident')
          .call({
            'incidentId': incidentId,
            'deviceId': deviceId,
            'threatIntel': threatIntel,
            'securityContext': securityContext ?? {},
          });
      return IncidentReceipt.fromJson(result.data);
    } catch (e) {
      rethrow;
    }
  }

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
