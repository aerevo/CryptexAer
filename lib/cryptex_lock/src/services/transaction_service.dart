// 🏦 TRANSACTION SERVICE V2.1 (FIREBASE INTEGRATED)
// Status: CONNECTED 🟢
// Updates:
// 1. Integrasi Firestore (Audit Trail & Blacklist Check)
// 2. Real SHA-256 Hashing
// 3. Firebase Auth Session Validation

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

// 🔥 FIREBASE IMPORTS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  static const bool useMockData = true; // Still true for Development
  static const Duration timeout = Duration(seconds: 10);
  
  // 🔐 SECRET SALT (In production, fetch this from Remote Config)
  static const String _secretSalt = 'Z_KINETIC_PRO_FIREBASE_SALT_V2';

  // ============================================
  // MAIN ENTRY POINT
  // ============================================
  static Future<TransactionData> fetchCurrentTransaction() async {
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
  // 🛡️ FIREBASE SECURITY LAYER (NEW)
  // ============================================
  static Future<void> _performSecurityCheck() async {
    final user = FirebaseAuth.instance.currentUser;
    
    // Pastikan user dah login (Anonymous pun takpe)
    if (user == null) {
      throw SecurityException('NO_ACTIVE_SESSION: User not logged in to Firebase');
    }

    try {
      final db = FirebaseFirestore.instance;
      
      // 1. Semak Blacklist (Baca dari 'blacklisted_devices')
      // Rule: allow read: if request.auth != null;
      final blacklistDoc = await db.collection('blacklisted_devices').doc(user.uid).get();
      
      if (blacklistDoc.exists) {
        // Jika device disenarai hitam, halang akses serta merta!
        throw SecurityException('DEVICE_BLACKLISTED: Access Denied by HQ');
      }

      // 2. Cipta Audit Trail (Tulis ke 'security_incidents')
      // Rule: allow create: if request.auth != null;
      // Kita log bahawa user ini cuba akses transaksi.
      await db.collection('security_incidents').add({
        'type': 'transaction_request',
        'uid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'authorized_mock_mode',
        'description': 'User requested transaction data via Z-Kinetic App'
      });

    } catch (e) {
      if (e is SecurityException) rethrow; // Jangan telan SecurityException
      
      // Kalau error lain (contoh: internet slow), kita log di console tapi benarkan proceed (fail-open for dev)
      print('⚠️ Firebase Check Warning: $e'); 
    }
  }

  // ============================================
  // MOCK MODE (Testing & Development)
  // ============================================
  static Future<TransactionData> _fetchMockTransaction() async {
    // Simulate network delay (500ms - 1200ms)
    final random = Random();
    final delay = 500 + random.nextInt(700);
    await Future.delayed(Duration(milliseconds: delay));

    // Generate realistic random amount
    final amounts = [
      'RM 1,250.00',
      'RM 5,000.00',
      'RM 12,850.50',
      'RM 25,000.00',
      'RM 50,000.00',
      'RM 100,500.75',
      'RM 250,000.00',
    ];
    
    final selectedAmount = amounts[random.nextInt(amounts.length)];
    final timestamp = DateTime.now();
    final txnId = 'TXN-${timestamp.millisecondsSinceEpoch}-${random.nextInt(9999)}';

    // 🔥 GENERATE REAL SHA-256 HASH
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

  // ============================================
  // FIREBASE DATA MODE (Future Implementation)
  // ============================================
  static Future<TransactionData> _fetchFromFirebase() async {
    // Placeholder untuk bila kita simpan data transaksi sebenar dalam Firestore
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
    // Remove formatting untuk consistent hashing
    final cleanAmount = amount
        .replaceAll('RM', '')
        .replaceAll(' ', '')
        .replaceAll(',', '')
        .trim();

    // Construct hash input dengan specific order
    final hashInput = [
      cleanAmount,
      txnId,
      timestamp.millisecondsSinceEpoch.toString(),
      _secretSalt,
    ].join('|');

    // Generate SHA-256 hash
    final bytes = utf8.encode(hashInput);
    final digest = sha256.convert(bytes);
    
    // Return first 32 characters (uppercase)
    return digest.toString().substring(0, 32).toUpperCase();
  }

  // ============================================
  // VALIDATION HELPER
  // ============================================
  static bool validateTransaction(TransactionData data) {
    // 1. Check checksum
    if (!data.verifyIntegrity()) {
      return false;
    }

    // 2. Verify hash
    final expectedHash = _generateSecureHash(
      amount: data.amount,
      txnId: data.transactionId,
      timestamp: data.timestamp,
    );

    return data.securityHash == expectedHash;
  }
}

// ============================================
// CUSTOM EXCEPTIONS
// ============================================
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  @override
  String toString() => 'SecurityException: $message';
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => 'HttpException: $message';
}
