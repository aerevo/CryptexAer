
class ClaConfig {
  final Duration minSolveTime;
  final double minShake;
  final List<int> secret;
  final int thresholdAmount;
  final bool enableSensors;

  const ClaConfig({
    required this.minSolveTime,
    required this.minShake,
    required this.secret,
    required this.thresholdAmount,
    this.enableSensors = true,
  });
}
