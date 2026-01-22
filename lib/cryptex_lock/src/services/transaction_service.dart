// 🏦 TRANSACTION SERVICE V2.2 (REMOTE CONFIG ENHANCED)
// Status: CONNECTED 🟢
// Updates:
// 1. Integrasi Firestore (Audit Trail & Blacklist Check)
// 2. Real SHA-256 Hashing dengan Dynamic Salt (Remote Config)
// 3. Firebase Auth Session Validation

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

// 🔥 FIREBASE IMPORTS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

// ============================================
// TRANSACTION DATA MODEL
// ============================================
class TransactionData {
  final String amount;           // Display value (RM 50,000.00)
  final String securityHash;     // SHA-256 hash untuk verification
  final String transactionId;    // Unique TXN ID
  final DateTime timestamp;      // Server timestamp
  final String checksum;         // Extra integrity layer

  TransactionData({
    required this.amount, 
    required this.securityHash,
    required this.transactionId,
    DateTime? timestamp,
    String? checksum,
  }) : timestamp = timestamp ?? DateTime.now(),
       checksum = checksum ?? _generateChecksum(amount, transactionId);

  // Generate checksum untuk extra validation
  static String _generateChecksum(String amount, String txnId) {
    final input = '$amount:$txnId';
    return md5.convert(utf8.encode(input)).toString().substring(0, 8);
  }

  // Verify integrity
  bool verifyIntegrity() {
    final expectedChecksum = _generateChecksum(amount, transactionId);
    return checksum == expectedChecksum;
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'securityHash': securityHash,
    'transactionId': transactionId,
    'timestamp': timestamp.toIso8601String(),
    'checksum': checksum,
  };

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    return TransactionData(
      amount: json['amount'],
      securityHash: json['securityHash'],
      transactionId: json['transactionId'],
      timestamp: DateTime.parse(json['timestamp']),
      checksum: json['checksum'],
    );
  }
}

// ============================================
// TRANSACTION SERVICE (THE PIPELINE)
// ============================================
class TransactionService {
  // 🎛️ CONFIGURATION
  static const bool useMockData = true; 
  static const Duration timeout = Duration(seconds: 10);
  
  // 🔐 DYNAMIC SALT (Fetched from Firebase Remote Config)
  static String _secretSalt = '';

  // ============================================
  // MAIN ENTRY POINT
  // ============================================
  static Future<TransactionData> fetchCurrentTransaction() async {
    // 🛡️ STEP 0: INITIALIZE REMOTE CONFIG
    await _initRemoteConfig();

    // 🛡️ STEP 1: FIREBASE SECURITY CHECK
    await _performSecurityCheck();

    // 🛡️ STEP 2: FETCH DATA
    if (useMockData) {
      return _fetchMockTransaction();
    } else {
      return _fetchFromFirebase();
    }
  }

  // ============================================
  // 🛰️ REMOTE CONFIG INITIALIZATION
  // ============================================
  static Future<void> _initRemoteConfig() async {
    if (_secretSalt.isNotEmpty) return;

    final remoteConfig = FirebaseRemoteConfig.instance;
    try {
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();
      _secretSalt = remoteConfig.getString('security_salt');
      
      if (_secretSalt.isEmpty) {
        _secretSalt = 'Z_KINETIC_FALLBACK_SALT_V2'; // Emergency Fallback
      }
    } catch (e) {
      _secretSalt = 'Z_KINETIC_OFFLINE_SALT_V2';
      print('⚠️ Remote Config Error: $e');
    }
  }

  // ============================================
  // 🛡️ FIREBASE SECURITY LAYER
  // ============================================
  static Future<void> _performSecurityCheck() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      throw SecurityException('NO_ACTIVE_SESSION: User not logged in to Firebase');
    }

    try {
      final db = FirebaseFirestore.instance;
      
      final blacklistDoc = await db.collection('blacklisted_devices').doc(user.uid).get();
      
      if (blacklistDoc.exists) {
        throw SecurityException('DEVICE_BLACKLISTED: Access Denied by HQ');
      }

      await db.collection('security_incidents').add({
        'type': 'transaction_request',
        'uid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'authorized_secure_mode',
        'description': 'User requested transaction data via Z-Kinetic App'
      });

    } catch (e) {
      if (e is SecurityException) rethrow;
      print('⚠️ Firebase Check Warning: $e'); 
    }
  }

  // ============================================
  // MOCK MODE (Testing & Development)
  // ============================================
  static Future<TransactionData> _fetchMockTransaction() async {
    final random = Random();
    final delay = 500 + random.nextInt(700);
    await Future.delayed(Duration(milliseconds: delay));

    final amounts = [
      'RM 1,250.00', 'RM 5,000.00', 'RM 12,850.50', 'RM 25,000.00',
      'RM 50,000.00', 'RM 100,500.75', 'RM 250,000.00',
    ];
    
    final selectedAmount = amounts[random.nextInt(amounts.length)];
    final timestamp = DateTime.now();
    final txnId = 'TXN-${timestamp.millisecondsSinceEpoch}-${random.nextInt(9999)}';

    final hash = _generateSecureHash(
      amount: selectedAmount,
      txnId: txnId,
      timestamp: timestamp,
    );

    return TransactionData(
      amount: selectedAmount,
      securityHash: hash,
      transactionId: txnId,
      timestamp: timestamp,
    );
  }

  static Future<TransactionData> _fetchFromFirebase() async {
    throw UnimplementedError('Live Firebase data fetching not enabled yet.');
  }

  // ============================================
  // CRYPTOGRAPHIC HASH GENERATION
  // ============================================
  static String _generateSecureHash({
    required String amount,
    required String txnId,
    required DateTime timestamp,
  }) {
    final cleanAmount = amount
        .replaceAll('RM', '')
        .replaceAll(' ', '')
        .replaceAll(',', '')
        .trim();

    final hashInput = [
      cleanAmount,
      txnId,
      timestamp.millisecondsSinceEpoch.toString(),
      _secretSalt,
    ].join('|');

    final bytes = utf8.encode(hashInput);
    final digest = sha256.convert(bytes);
    
    return digest.toString().substring(0, 32).toUpperCase();
  }

  static bool validateTransaction(TransactionData data) {
    if (!data.verifyIntegrity()) {
      return false;
    }

    final expectedHash = _generateSecureHash(
      amount: data.amount,
      txnId: data.transactionId,
      timestamp: data.timestamp,
    );

    return data.securityHash == expectedHash;
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  @override
  String toString() => 'SecurityException: $message';
}
