import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// ============================================
// VERDICT MODEL
// ============================================
class BlackBoxVerdict {
  final bool allowed;
  final String verdict;
  final double confidence;
  final String riskScore;

  BlackBoxVerdict({
    required this.allowed,
    required this.verdict,
    required this.confidence,
    required this.riskScore,
  });

  factory BlackBoxVerdict.fromJson(Map<String, dynamic> json) {
    return BlackBoxVerdict(
      allowed: json['allowed'] == true,
      verdict: json['verdict']?.toString() ?? 'UNKNOWN',
      confidence: double.tryParse(json['confidence']?.toString() ?? '0.0') ?? 0.0,
      riskScore: json['riskScore']?.toString() ?? 'MEDIUM',
    );
  }

  factory BlackBoxVerdict.offline() => BlackBoxVerdict(
    allowed: false, 
    verdict: 'OFFLINE_ERR', 
    confidence: 0.0, 
    riskScore: 'HIGH'
  );
}

// ============================================
// FIREBASE REST CLIENT (GEN 2)
// ============================================
class FirebaseBlackBoxClient {
  // 🚀 URL SERVER BARU KITA!
  final String baseUrl = "https://asia-southeast1-z-kinetic.cloudfunctions.net/api";
  
  // 🔑 API KEY (Pastikan sama dengan yang ada kat Firestore nanti)
  final String apiKey = "zk_live_f9cd989306b3597e15f3974d053f85ee";

  /// 1. MINTA CABARAN (Get Challenge)
  Future<Map<String, dynamic>?> getChallenge(String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenge'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode({'deviceId': deviceId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Challenge Error: $e');
      return null;
    }
  }

  /// 2. SAHKAN BIOMETRIK (Verify)
  Future<BlackBoxVerdict> verify({
    required String nonce,
    required List<int> userResponse,
    required BiometricSession biometric,
    required String deviceId,
  }) async {
    try {
      if (kDebugMode) print('🧠 Sending AI Analysis to Gen 2 Server...');

      final response = await http.post(
        Uri.parse('$baseUrl/verify'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode({
          'nonce': nonce,
          'userResponse': userResponse,
          'deviceId': deviceId,
          'biometricData': _serializeBiometric(biometric), // ⬅️ AI Data kat sini
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BlackBoxVerdict.fromJson(data);
      } else {
        return BlackBoxVerdict.offline();
      }
    } catch (e) {
      if (kDebugMode) print('💥 Verification Crash: $e');
      return BlackBoxVerdict.offline();
    }
  }

  /// Tukar data sensor jadi JSON (AI Ready)
  Map<String, dynamic> _serializeBiometric(BiometricSession session) {
    return {
      'motion': session.motionEvents.map((e) => {
        'm': e.magnitude,
        't': e.timestamp.millisecondsSinceEpoch,
      }).toList(),
      'touch': session.touchEvents.map((e) => {
        'p': e.pressure,
        'v': (e.velocityX + e.velocityY) / 2, // Velocity average
      }).toList(),
      'duration': session.duration.inMilliseconds,
    };
  }
}
