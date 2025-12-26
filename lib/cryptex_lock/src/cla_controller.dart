import 'dart:math';
import 'package:flutter/foundation.dart'; // Perlu untuk ChangeNotifier
import 'cla_config.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  // State
  bool _jammed = false;
  DateTime? _jamUntil;
  late List<int> currentValues; // Nilai semasa roda

  ClaController(this.config) {
    // Mula dengan semua roda pada nilai rawak (selain rahsia) untuk keselamatan
    resetWheels();
  }

  /// Reset roda ke nilai rawak (0-9)
  void resetWheels() {
    final rand = Random();
    // Kita buat 5 roda (hardcoded 5 untuk V1 ini)
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    notifyListeners();
  }

  /// Update nilai bila user pusing roda
  void updateWheel(int index, int value) {
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      // Jangan notifyListeners di sini sebab ia akan rebuild UI terlalu kerap (performance)
    }
  }

  /// Memeriksa status Jammed
  bool get isJammed {
    if (_jamUntil == null) return false;
    if (DateTime.now().isAfter(_jamUntil!)) {
      _jamUntil = null;
      _jammed = false;
      return false;
    }
    return true;
  }

  /// Mengaktifkan perangkap (Honeypot Trigger)
  void jam() {
    _jammed = true;
    _jamUntil = DateTime.now().add(config.jamCooldown);
    notifyListeners();
  }

  /// Validasi masa (Time Inertia Defense)
  bool validateSolveTime(Duration elapsed) {
    return elapsed >= config.minSolveTime;
  }

  /// Validasi gegaran (Physical Presence Defense)
  bool validateShake(double avgShake) {
    return avgShake >= config.minShake;
  }

  /// Adakah transaksi ini cukup besar untuk memerlukan CLA?
  bool shouldRequireLock(double amount) {
    return amount >= config.thresholdAmount;
  }

  /// Semakan Kod Rahsia + Semakan Perangkap
  bool verifyCode() {
    // 1. Semakan Perangkap: Adakah pengguna pilih '0' (Zero Trap)?
    // Dalam Visi Kapten: "Zero Trap Logic".
    // Jika mana-mana roda adalah '0', kita anggap ia perangkap bot -> JAM!
    if (currentValues.contains(0)) {
      jam();
      return false;
    }

    // 2. Semakan Kod
    // Kita bandingkan currentValues dengan config.secret
    // Pastikan panjang sama
    if (currentValues.length != config.secret.length) return false;

    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) {
        return false;
      }
    }
    
    return true;
  }
}
