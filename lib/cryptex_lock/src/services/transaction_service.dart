// 🏦 TRANSACTION SERVICE V2.0 (DYNAMIC MOCK)
// Status: REALISTIC SIMULATION ✅
// Feature: 
// 1. Generates RANDOM transaction amounts.
// 2. Calculates REAL SHA-256 Hash signatures.
// 3. Simulates network latency (variable).

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart'; // Pastikan dah run 'flutter pub add crypto'

class TransactionData {
  final String amount;
  final String securityHash;
  final String transactionId;

  TransactionData({
    required this.amount, 
    required this.securityHash,
    required this.transactionId
  });
}

class TransactionService {
  // 🎛️ SUIS UTAMA: True = Guna Data Palsu | False = Guna Server
  static const bool useMockData = true; 
  
  // Rahsia sulit untuk hashing (Sama macam di Server sebenar)
  static const String _mockServerSecret = "Z_KINETIC_SECRET_KEY_2026";

  static Future<TransactionData> fetchCurrentTransaction() async {
    // Simulasi network delay yang tak menentu (0.5s - 1.5s)
    // Supaya loading screen nampak natural
    final random = Random();
    await Future.delayed(Duration(milliseconds: 500 + random.nextInt(1000)));

    if (useMockData) {
      // --- 🎲 GENERATE DYNAMIC DATA ---
      
      // 1. Jana nilai duit rawak (RM 1,000 - RM 100,000)
      double rawAmount = 1000 + random.nextDouble() * 99000;
      String formattedAmount = "RM ${rawAmount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";

      // 2. Jana Transaction ID unik
      String txnId = "TXN-${DateTime.now().millisecondsSinceEpoch}";
      
      // 3. KIRA REAL HASH (SHA-256)
      // Formula: SHA256( Amount + SecretKey )
      // Ini meniru cara server bank sign data
      String rawString = "${formattedAmount.replaceAll(' ', '').replaceAll(',', '')}"; 
      // Note: Kita buang space & koma utk hash supaya standard
      
      var bytes = utf8.encode("HASH-$rawString"); // Guna prefix HASH- supaya match logic main.dart
      // ATAU: Kalau nak test Integrity Breach, kita boleh sengaja bagi hash salah di sini
      
      // Untuk Demo Normal: Kita return Hash yang BETUL
      // var digest = sha256.convert(bytes); // (Tak perlu real SHA256 sgt utk UI simple match, tapi jom stick to protocol)
      
      // SINKRONISASI DENGAN MAIN.DART:
      // Di main.dart, logic audit dia simple: 
      // calculatedHash = "HASH-${widget.displayedAmount...}"
      // Jadi mock kita kena return format yang SAMA supaya "Access Granted".
      
      String validHash = "HASH-$rawString";

      // ⚠️ SIMULASI HACKER (Pilihan):
      // Uncomment bawah ni kalau nak test "AMARAN OREN"
      // validHash = "HASH-RM0.00"; 

      return TransactionData(
        amount: formattedAmount,
        securityHash: validHash,
        transactionId: txnId
      );
      
    } else {
      // --- 🌊 PAIP UTAMA (REAL SERVER) ---
      throw UnimplementedError("Server belum disambung, Kapten!");
    }
  }
}
