enum SecurityState {
  LOCKED,           // Sedia
  VALIDATING,       // Proses
  UNLOCKED,         // Berjaya
  SOFT_LOCK,        // Amaran Salah
  HARD_LOCK,        // JAMMED
  BOT_SIMULATION,   // Ujian
  ROOT_WARNING,     // <--- INI PERKATAAN BARU YG HILANG TADI
  COMPROMISED       // Jika perlu hard block
}

class ClaConfig {
  final List<int> secret;
  final Duration minSolveTime;
  final double minShake;
  final Duration jamCooldown;
  final Duration softLockCooldown;
  final int maxAttempts;
  final double thresholdAmount;

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
