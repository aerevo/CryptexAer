enum ClaResult { success, fail, jammed }

class ClaConfig {
  final Duration minSolveTime;
  final double minShake;
  final int thresholdAmount;

  const ClaConfig({
    required this.minSolveTime,
    required this.minShake,
    required this.thresholdAmount,
  });
}