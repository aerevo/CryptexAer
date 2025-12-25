enum ClaResult { success, fail, jammed }

class ClaConfig {
  final Duration minSolveTime;
  final double minShake; // sederhana ~0.18
  final List<int> secret; // kombinasi sebenar

  const ClaConfig({
    required this.minSolveTime,
    required this.minShake,
    required this.secret,
  });
}
