// lib/cryptex_lock/src/cla_config.dart

class ClaConfig {
  /// Kombinasi rahsia untuk kunci (Senarai integer)
  final List<int> secret;
  
  /// Masa minimum interaksi manusia (Anti-Bot Timer)
  final Duration minSolveTime;
  
  /// Tahap gegaran minimum untuk membuktikan kehadiran fizikal
  final double minShake;
  
  /// Tempoh masa sistem terkunci jika 'Zero Trap' disentuh atau bot dikesan
  final Duration jamCooldown;
  
  /// Nilai transaksi minimum untuk mengaktifkan CLA
  final double thresholdAmount;

  const ClaConfig({
    required this.secret,
    required this.minSolveTime,
    required this.minShake,
    required this.jamCooldown,
    required this.thresholdAmount,
  });
}
