import 'dart:math';
import 'package:flutter/foundation.dart';
import 'cla_config.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  // State
  bool _jammed = false;
  DateTime? _jamUntil;
  late List<int> currentValues;
  
  // ANALISIS BIOMETRIK: Menyimpan sampel gegaran untuk analisis statistik
  List<double> _shakeSamples = [];

  ClaController(this.config) {
    resetWheels();
  }

  void resetWheels() {
    final rand = Random();
    // Rawakkan nombor awal supaya bot susah nak teka
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    _shakeSamples.clear(); // Kosongkan sampel biometrik
    notifyListeners();
  }

  void updateWheel(int index, int value) {
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      // Jangan notifyListeners di sini untuk kelancaran UI (performance)
    }
  }

  // Merekod data sensor untuk analisis corak
  void recordShakeSample(double magnitude) {
    _shakeSamples.add(magnitude);
    // Simpan hanya 100 sampel terakhir untuk jimat memori
    if (_shakeSamples.length > 100) {
      _shakeSamples.removeAt(0);
    }
  }

  bool get isJammed {
    if (_jamUntil == null) return false;
    if (DateTime.now().isAfter(_jamUntil!)) {
      _jamUntil = null;
      _jammed = false;
      return false;
    }
    return true;
  }

  void jam() {
    _jammed = true;
    _jamUntil = DateTime.now().add(config.jamCooldown);
    notifyListeners();
  }

  // --- LOGIK "PROOF OF HUMANITY" (LEVEL VISI KAPTEN) ---

  // 1. Analisis Masa: Manusia perlukan masa kognitif
  bool validateSolveTime(Duration elapsed) {
    // Jika terlalu pantas (< 2 saat), ia adalah skrip/bot
    return elapsed >= config.minSolveTime;
  }

  // 2. Analisis Biometrik: Sisihan Piawai (Standard Deviation)
  // Bot/Emulator = Varians Sifar (0.0).
  // Manusia = Varians Kecil (Micro-jitters).
  bool validateHumanBehavior() {
    if (_shakeSamples.isEmpty) return false;

    // Kira Purata (Mean)
    double sum = _shakeSamples.reduce((a, b) => a + b);
    double mean = sum / _shakeSamples.length;

    // Kira Varians (Variance)
    double varianceSum = 0.0;
    for (var sample in _shakeSamples) {
      varianceSum += pow((sample - mean), 2);
    }
    double variance = varianceSum / _shakeSamples.length;
    
    // Kira Sisihan Piawai (Standard Deviation)
    double stdDev = sqrt(variance);

    print("BIO-LOG: Mean: ${mean.toStringAsFixed(4)} | StdDev: ${stdDev.toStringAsFixed(4)}");

    // LOGIK EMPAYAR:
    // 1. Mesti ada purata gegaran minima (threshold).
    // 2. TAPI, mesti ada variasi (stdDev > 0.01). Jika stdDev == 0, itu emulator.
    
    bool hasMinimumShake = mean >= config.minShake;
    bool isNotRobotPerfect = stdDev > 0.01; // Bot selalunya perfect 0 variance

    return hasMinimumShake && isNotRobotPerfect;
  }

  bool shouldRequireLock(double amount) {
    return amount >= config.thresholdAmount;
  }

  bool verifyCode() {
    // 1. TRAP CHECK (Zero Trap)
    // Jika ada '0', sistem jammed. Ini perangkap honeypot.
    if (currentValues.contains(0)) {
      jam(); 
      return false;
    }

    // 2. CODE CHECK
    if (currentValues.length != config.secret.length) return false;
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) {
        return false; // Salah kod tapi bukan trap
      }
    }
    
    return true;
  }
}
