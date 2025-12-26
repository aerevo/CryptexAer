import 'dart:math';
import 'package:flutter/foundation.dart';
import 'cla_config.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  // State
  bool _jammed = false;
  DateTime? _jamUntil;
  late List<int> currentValues;
  
  // Data Analisis Biometrik
  List<double> _shakeSamples = [];
  double debugMaxShake = 0.0;

  ClaController(this.config) {
    resetWheels();
  }

  void resetWheels() {
    final rand = Random();
    // 5 Roda, nilai rawak mula
    currentValues = List.generate(5, (index) => rand.nextInt(10));
    _shakeSamples.clear();
    debugMaxShake = 0.0;
    notifyListeners();
  }

  void updateWheel(int index, int value) {
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
    }
  }

  // Merekod data sensor (tanpa notify UI berlebihan untuk performance)
  void recordShakeSample(double magnitude) {
    _shakeSamples.add(magnitude);
    if (magnitude > debugMaxShake) {
      debugMaxShake = magnitude;
    }
    // Simpan 200 sampel terakhir sahaja (jimat memori)
    if (_shakeSamples.length > 200) {
      _shakeSamples.removeAt(0);
    }
    // notifyListeners(); // Tutup notify kerap untuk UI silent
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

  // --- LOGIK "PROOF OF HUMANITY" ---
  bool validateHumanBehavior() {
    if (_shakeSamples.isEmpty) return false;

    // 1. Analisis Purata (Inersia)
    double sum = _shakeSamples.reduce((a, b) => a + b);
    double mean = sum / _shakeSamples.length;

    // 2. Kriteria Lulus:
    // a. Peak Force: Mesti ada gegaran maksima > 0.15 (Tanda pergerakan sedar)
    // b. Mean: Purata mesti > 0.02 (Tanda pergerakan mikro berterusan/tangan hidup)
    bool hasLifeSign = debugMaxShake > config.minShake;
    bool hasInertia = mean > 0.02; 

    // Reset sampel selepas semakan untuk sesi seterusnya
    _shakeSamples.clear();
    debugMaxShake = 0.0;

    return hasLifeSign && hasInertia;
  }

  bool validateSolveTime(Duration elapsed) {
    return elapsed >= config.minSolveTime;
  }

  bool shouldRequireLock(double amount) {
    return amount >= config.thresholdAmount;
  }

  bool verifyCode() {
    // 1. TRAP CHECK (Zero Trap / Honeypot)
    if (currentValues.contains(0)) {
      jam(); 
      return false;
    }

    // 2. SECRET CODE CHECK
    if (currentValues.length != config.secret.length) return false;
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) {
        return false;
      }
    }
    
    return true;
  }
}
