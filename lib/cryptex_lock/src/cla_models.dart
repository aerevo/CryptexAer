enum SecurityState {
  LOCKED,           // Sedia
  VALIDATING,       // Sedang semak
  UNLOCKED,         // Berjaya
  SOFT_LOCK,        // Salah Key in (Amaran)
  HARD_LOCK,        // Jammed (Kena tunggu)
  BOT_SIMULATION,   // Mode Test Robot
  ROOT_WARNING,     // Anjing Penjaga Menggonggong
  COMPROMISED       // Kena Block Terus
}

class ClaConfig {
  final List<int> secret;
  final Duration minSolveTime;
  final double minShake;
  final Duration jamCooldown;
  final Duration softLockCooldown;
  final int maxAttempts;
  final double thresholdAmount;
  final bool enableSensors; // Master Switch

  const ClaConfig({
    required this.secret,
    required this.minSolveTime,
    required this.minShake,
    required this.jamCooldown,
    this.softLockCooldown = const Duration(seconds: 3),
    this.maxAttempts = 3, 
    required this.thresholdAmount,
    this.enableSensors = true,
  });
}
