/// STATUS KESELAMATAN (STATE MACHINE)
/// Ini adalah bahasa yang digunakan oleh Blackbox untuk bercakap dengan UI.
enum SecurityState {
  LOCKED,           // Sedia untuk input
  VALIDATING,       // Sedang memproses (Loading...)
  UNLOCKED,         // Berjaya (Access Granted)
  SOFT_LOCK,        // Amaran (Salah kod / Terlalu laju) - Denda 3 saat
  HARD_LOCK,        // JAMMED (Bot/Honeypot) - Denda lama (System Lockdown)
  BOT_SIMULATION    // Mod Ujian (Kapten test sendiri)
}

/// KONFIGURASI BLACKBOX
/// Ini adalah setting yang Bank boleh ubah bila beli SDK Kapten.
class ClaConfig {
  final List<int> secret;          // Kod Rahsia
  final Duration minSolveTime;     // Masa minimum (Anti-Macro)
  final double minShake;           // Ambang biometrik
  final Duration jamCooldown;      // Masa denda Hard Lock
  final Duration softLockCooldown; // Masa denda Soft Lock
  final int maxAttempts;           // Had percubaan sebelum Hard Lock
  final double thresholdAmount;    // Nilai transaksi minimum

  const ClaConfig({
    required this.secret,
    required this.minSolveTime,
    required this.minShake,
    required this.jamCooldown,
    this.softLockCooldown = const Duration(seconds: 3),
    this.maxAttempts = 3, 
    required this.thresholdAmount,
  });
}
