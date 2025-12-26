import 'dart:math';
import 'package:flutter/foundation.dart';
import 'cla_config.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  // State
  bool _jammed = false;
  DateTime? _jamUntil;
  late List<int> currentValues;
  
  // DIAGNOSTIK: Untuk paparan di skrin
  double debugCurrentShake = 0.0;
  double debugMaxShake = 0.0;
  double debugAvgShake = 0.0;

  // Simpan data untuk analisis
  List<double> _shakeSamples = [];

  ClaController(this.config) {
    resetWheels();
  }

  void resetWheels() {
    final rand = Random();
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    _shakeSamples.clear();
    debugMaxShake = 0.0;
    notifyListeners();
  }

  void updateWheel(int index, int value) {
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      // updateWheel tak perlu notifyListeners kerap sangat
    }
  }

  void recordShakeSample(double magnitude) {
    _shakeSamples.add(magnitude);
    
    // Update data diagnostik
    debugCurrentShake = magnitude;
    if (magnitude > debugMaxShake) {
      debugMaxShake = magnitude;
    }
    
    // Limit memori
    if (_shakeSamples.length > 200) {
      _shakeSamples.removeAt(0);
    }
    
    // Notify supaya UI boleh tunjuk nombor bergerak (Real-time update)
    notifyListeners();
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

  // LOGIK V3: LEBIH ROBUST UNTUK HARDWARE BERBEZA
  bool validateHumanBehavior() {
    if (_shakeSamples.isEmpty) return false;

    // Kira Purata
    double sum = _shakeSamples.reduce((a, b) => a + b);
    double mean = sum / _shakeSamples.length;
    debugAvgShake = mean;

    // Kriteria 1: Mesti ada gegaran maksimum yang signifikan (Bukan meja mati)
    // Meja mati biasanya < 0.05. Tangan manusia biasanya > 0.15
    bool hasLifeSign = debugMaxShake > 0.15;

    // Kriteria 2: Purata gegaran mesti wujud (tapi tak perlu tinggi sangat)
    bool hasInertia = mean > 0.02;

    print("DIAGNOSTIC: Max: $debugMaxShake | Mean: $mean | Result: ${hasLifeSign && hasInertia}");

    return hasLifeSign && hasInertia;
  }

  bool validateSolveTime(Duration elapsed) {
    return elapsed >= config.minSolveTime;
  }

  bool shouldRequireLock(double amount) {
    return amount >= config.thresholdAmount;
  }

  bool verifyCode() {
    // 1. Check ZERO TRAP
    if (currentValues.contains(0)) {
      jam(); 
      return false;
    }

    // 2. Check SECRET CODE
    if (currentValues.length != config.secret.length) return false;
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) {
        return false;
      }
    }
    
    return true;
  }
}
