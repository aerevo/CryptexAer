import 'dart:async'; // Perlu untuk Timer
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'cla_config.dart';

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  // Status
  bool _jammed = false;
  DateTime? _jamUntil;
  List<int> currentValues = [0, 0, 0, 0, 0];
  
  // Bot Simulation State
  bool isBotRunning = false;
  Timer? _botTimer;

  ClaController(this.config);

  void updateWheel(int index, int value) {
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
    }
  }
  
  // --- FUNGSI BARU: SIMULASI SERANGAN BOT ---
  void simulateBotAttack(VoidCallback onAttackFinished) {
    if (isBotRunning || isJammed) return;

    isBotRunning = true;
    notifyListeners(); // Update UI supaya nampak bot tengah jalan

    final rand = Random();
    int duration = 3000; // Bot menyerang selama 3 saat
    int tick = 0;
    
    // Timer ini akan berjalan sangat laju (setiap 50ms)
    _botTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      tick += 50;
      
      // Bot tukar semua nombor secara rawak
      for (int i = 0; i < currentValues.length; i++) {
        currentValues[i] = rand.nextInt(10);
      }
      notifyListeners(); // Paksa UI update nampak nombor berkelip

      // Bila masa tamat, berhenti dan cuba unlock
      if (tick >= duration) {
        timer.cancel();
        isBotRunning = false;
        notifyListeners();
        onAttackFinished(); // Panggil fungsi 'attemptUnlock' di widget
      }
    });
  }

  void stopBot() {
    _botTimer?.cancel();
    isBotRunning = false;
    notifyListeners();
  }

  // --- LOGIK ASAS (Kekal Sama) ---
  bool isTrapTriggered() {
    return currentValues.contains(0);
  }

  bool isCodeCorrect() {
    if (currentValues.length != config.secret.length) return false;
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) {
        return false;
      }
    }
    return true;
  }

  bool get isJammed {
    if (_jamUntil == null) return false;
    if (DateTime.now().isAfter(_jamUntil!)) {
      _jamUntil = null;
      _jammed = false;
      notifyListeners();
      return false;
    }
    return true;
  }

  void jam() {
    _jammed = true;
    _jamUntil = DateTime.now().add(config.jamCooldown);
    notifyListeners();
  }

  bool shouldRequireLock(double amount) {
    return amount >= config.thresholdAmount;
  }
  
  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }
}
