import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'cla_config.dart';
import 'cla_models.dart'; // Import Model Baru

class ClaController extends ChangeNotifier {
  final ClaConfig config;

  // --- STATE (STATUS) ---
  SecurityState _state = SecurityState.LOCKED;
  SecurityState get state => _state;

  // --- MEMORY (INGATAN) ---
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  List<int> currentValues = [0, 0, 0, 0, 0];
  
  // --- BOT SIMULATION VARS ---
  Timer? _botTimer;

  // Constructor
  ClaController(this.config) {
    _resetInternal();
  }

  // Reset dalaman (Private)
  void _resetInternal() {
    // Hanya reset jika sistem tidak JAMMED
    if (_state != SecurityState.HARD_LOCK) {
      final rand = Random();
      // Scramble nombor untuk keselamatan (Anti-Pattern)
      currentValues = List.generate(5, (index) => rand.nextInt(10));
      notifyListeners();
    }
  }

  // Update Roda (Dipanggil oleh UI)
  void updateWheel(int index, int value) {
    // Kalau sistem tengah sibuk atau jammed, tolak input
    if (_state == SecurityState.HARD_LOCK || 
        _state == SecurityState.VALIDATING || 
        _state == SecurityState.BOT_SIMULATION) return;
    
    if (index >= 0 && index < currentValues.length) {
      currentValues[index] = value;
      // notifyListeners(); // Optional: Optimization (Silent Update)
    }
  }

  // --- LOGIK TERAS (THE BLACK BOX LOGIC) ---

  // 1. Semak Denda (Perlu dipanggil sentiasa oleh UI)
  void checkLockStatus() {
    if (_lockoutUntil != null) {
      if (DateTime.now().isAfter(_lockoutUntil!)) {
        // Denda tamat -> Bebaskan sistem
        _lockoutUntil = null;
        _state = SecurityState.LOCKED;
        _failedAttempts = 0; // Reset dosa
        _resetInternal(); // Scramble roda balik
        notifyListeners();
      }
      // Jika belum tamat, kekal dalam HARD_LOCK
    }
  }

  // 2. Fungsi Validasi Utama (Jantung Sistem)
  Future<void> validateAttempt({
    required bool hasPhysicalMovement,
    required Duration solveTime,
  }) async {
    
    // Semak jika sistem masih kena denda
    checkLockStatus();
    if (_state == SecurityState.HARD_LOCK || _state == SecurityState.SOFT_LOCK) return;

    // Tukar status ke 'VALIDATING' (UI akan tunjuk loading)
    _state = SecurityState.VALIDATING;
    notifyListeners();

    // Simulasi pengiraan kriptografi (rasa 'berat' sikit)
    await Future.delayed(const Duration(milliseconds: 600));

    // A. SEMAK HONEYPOT (DOSA BESAR)
    // Jika ada '0', sistem tahu ini serangan rawak -> HARD LOCK
    if (currentValues.contains(0)) {
      _triggerHardLock();
      return;
    }

    // B. SEMAK FIZIKAL (DOSA BESAR)
    // Jika tiada gegaran tangan -> HARD LOCK
    if (!hasPhysicalMovement) {
      _triggerHardLock();
      return;
    }

    // C. SEMAK KOD RAHSIA (KUNCI UTAMA)
    if (_isCodeCorrect()) {
      // BERJAYA
      _state = SecurityState.UNLOCKED;
      _failedAttempts = 0;
      notifyListeners();
    } else {
      // GAGAL (Salah Kod)
      _handleSoftFail();
    }
  }

  // --- FUNGSI SOKONGAN (PRIVATE) ---

  bool _isCodeCorrect() {
    if (currentValues.length != config.secret.length) return false;
    for (int i = 0; i < config.secret.length; i++) {
      if (currentValues[i] != config.secret[i]) return false;
    }
    return true;
  }

  void _handleSoftFail() {
    _failedAttempts++;
    if (_failedAttempts >= config.maxAttempts) {
      // Dosa dah penuh (3x salah) -> HARD LOCK
      _triggerHardLock();
    } else {
      // Dosa kecil -> SOFT LOCK (Amaran)
      _state = SecurityState.SOFT_LOCK;
      notifyListeners();
      
      // Auto-release soft lock lepas 3 saat
      Future.delayed(config.softLockCooldown, () {
        if (_state == SecurityState.SOFT_LOCK) {
          _state = SecurityState.LOCKED;
          notifyListeners();
        }
      });
    }
  }

  void _triggerHardLock() {
    _state = SecurityState.HARD_LOCK;
    _lockoutUntil = DateTime.now().add(config.jamCooldown);
    notifyListeners();
  }

  // --- MOD UJIAN (BOT SIMULATION) ---
  void startBotSimulation(VoidCallback onFinished) {
    if (_state == SecurityState.HARD_LOCK) return;
    
    _state = SecurityState.BOT_SIMULATION;
    notifyListeners();

    final rand = Random();
    int ticks = 0;
    
    _botTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      ticks++;
      // Bot pusing roda rawak laju-laju
      for (int i = 0; i < currentValues.length; i++) {
        currentValues[i] = rand.nextInt(10);
      }
      notifyListeners();

      if (ticks >= 40) { // 2 saat
        timer.cancel();
        // Bot cuba unlock (tapi tanpa movement fizikal)
        validateAttempt(hasPhysicalMovement: false, solveTime: Duration.zero);
      }
    });
  }

  // Helper untuk UI tahu berapa lama lagi jammed
  String get remainingLockoutTime {
    if (_lockoutUntil == null) return "";
    final diff = _lockoutUntil!.difference(DateTime.now());
    return "${diff.inSeconds}";
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }
}
