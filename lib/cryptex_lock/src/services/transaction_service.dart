// 🏦 TRANSACTION SERVICE (The Data Pipeline)
// Status: MOCK MODE ACTIVE 🚰
// Fix: Added transactionId & Named Parameters to match main.dart

import 'dart:async';

class TransactionData {
  final String amount;
  final String securityHash;
  final String transactionId;

  // 🔥 PENTING: Guna Named Parameters ({}) supaya main.dart tak error
  TransactionData({
    required this.amount, 
    required this.securityHash,
    required this.transactionId
  });
}

class TransactionService {
  // 🎛️ SUIS UTAMA: True = Guna Data Palsu | False = Guna Server
  static const bool useMockData = true; 

  static Future<TransactionData> fetchCurrentTransaction() async {
    // Simulasi network loading (0.8 saat) supaya nampak real
    await Future.delayed(const Duration(milliseconds: 800));

    if (useMockData) {
      // --- 🚰 TANGKI AIR SIMPANAN (MOCK DATA) ---
      
      return TransactionData(
        amount: "RM 50,000.00",       // Nilai Display
        securityHash: "HASH-RM50.00", // Nilai Hash Sebenar
        transactionId: "TXN-${DateTime.now().millisecondsSinceEpoch}"
      );
      
    } else {
      // --- 🌊 PAIP UTAMA (REAL SERVER) ---
      /*
      final response = await http.get(Uri.parse('https://api.bank.com/secure/tx/current'));
      if (response.statusCode == 200) {
         // Pastikan JSON parsing pun guna named parameters nanti
         return TransactionData(
            amount: json['amount'],
            securityHash: json['hash'],
            transactionId: json['id']
         );
      }
      */
      throw UnimplementedError("Server belum disambung, Kapten!");
    }
  }
}
