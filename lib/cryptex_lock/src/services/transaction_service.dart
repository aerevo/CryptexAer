// 🏦 TRANSACTION SERVICE (The Pipeline Manager)
// Status: MOCK MODE (Placeholder Pintar)
// Note: Bila server dah siap, kita ubah fail ini SAHAJA. UI tak perlu sentuh.

class TransactionData {
  final String amount;
  final String securityHash;
  final bool isSecure;

  TransactionData(this.amount, this.securityHash, this.isSecure);
}

class TransactionService {
  // Ubah 'true' ke 'false' bila nak sambung server sebenar nanti
  static const bool useMockData = true; 

  static Future<TransactionData> fetchCurrentTransaction() async {
    // Simulasi loading (network delay)
    await Future.delayed(const Duration(milliseconds: 800));

    if (useMockData) {
      // --- MODE 1: MOCK (Guna ini sebelum Server siap) ---
      // Kapten boleh tukar value di sini sesuka hati untuk test
      return TransactionData(
        "RM 50,000.00",    // <--- Nilai Display
        "HASH-RM50.00",    // <--- Nilai Sebenar (Mismatch = Hack)
        false              // <--- Status (Hack detected)
      );
    } else {
      // --- MODE 2: REAL PRODUCTION (Bila Server dah siap) ---
      // final response = await http.get('https://api.bank.com/tx/123');
      // return TransactionData.fromJson(response.body);
      throw UnimplementedError("Server belum siap, bos!");
    }
  }
}
