// 🧠 SECURITY ENGINE (PURE LOGIC V3.0)
// Status: DECOUPLED & TESTABLE ✅
// Role: Input Sensor -> Output Verdict. No UI dependency.

import 'dart:math';
import 'cla_models.dart';

enum ThreatLevel { NONE, LOW, MEDIUM, HIGH, CRITICAL }

// Keputusan Akhir Engine
class ThreatVerdict {
  final bool allowed;
  final ThreatLevel level;
  final String reason;
  final double confidence;
  
  // Tambahan data forensik untuk reporting
  final double entropyScore;
  final double varianceScore;

  const ThreatVerdict({
    required this.allowed,
    required this.level,
    required this.reason,
    required this.confidence,
    this.entropyScore = 0.0,
    this.varianceScore = 0.0,
  });

  factory ThreatVerdict.allow(double confidence, {double entropy = 0, double variance = 0}) {
    return ThreatVerdict(
      allowed: true,
      level: ThreatLevel.NONE,
      reason: 'HUMAN_VERIFIED',
      confidence: confidence,
      entropyScore: entropy,
      varianceScore: variance,
    );
  }

  factory ThreatVerdict.deny(ThreatLevel level, String reason, {double entropy = 0}) {
    return ThreatVerdict(
      allowed: false,
      level: level,
      reason: reason,
      confidence: 0.0,
      entropyScore: entropy,
    );
  }
}

class SecurityEngine {
  final SecurityEngineConfig config;
  
  // Internal State
  double _lastEntropy = 0.0;
  double _lastConfidence = 0.0;

  SecurityEngine(this.config);

  // Getter untuk Controller baca status semasa
  double get lastEntropyScore => _lastEntropy;
  double get lastConfidenceScore => _lastConfidence;

  /// 🔥 ANALISIS UTAMA: Menilai adakah ini manusia atau bot?
  ThreatVerdict analyze({
    required List<MotionEvent> motionHistory,
    required int touchCount,
    required Duration interactionDuration,
  }) {
    // 1. Bot Check: Terlalu cepat?
    if (interactionDuration.inMilliseconds < 500) {
      return ThreatVerdict.deny(ThreatLevel.HIGH, 'SPEED_ANOMALY');
    }

    // 2. Bot Check: Tiada pergerakan langsung (Emulator/Script)?
    if (motionHistory.isEmpty) {
      // Jika sensor diabaikan dalam config, kita lepas (untuk testing)
      if (config.minMotionPresence <= 0) {
        return ThreatVerdict.allow(1.0); 
      }
      return ThreatVerdict.deny(ThreatLevel.MEDIUM, 'NO_MOTION_DATA');
    }

    // 3. Analisis Biometrik
    final entropy = _calculateEntropy(motionHistory);
    final variance = _calculateVariance(motionHistory);
    
    _lastEntropy = entropy;

    // 4. Logik Penilaian (The "Bank Grade" Decision)
    if (entropy < config.minEntropy) {
      // Pergerakan terlalu robotik/linear
      return ThreatVerdict.deny(
        ThreatLevel.HIGH, 
        'ROBOTIC_MOVEMENT_DETECTED',
        entropy: entropy
      );
    }

    if (variance < config.minVariance) {
      return ThreatVerdict.deny(
        ThreatLevel.MEDIUM, 
        'UNNATURAL_STABILITY',
        entropy: entropy
      );
    }

    // 5. Kira Keyakinan (Confidence Score)
    double score = (entropy * 0.6) + (variance * 40 * 0.4);
    score = score.clamp(0.0, 1.0);
    _lastConfidence = score;

    if (score < config.minConfidence) {
      return ThreatVerdict.deny(
        ThreatLevel.LOW, 
        'LOW_CONFIDENCE',
        entropy: entropy
      );
    }

    // ✅ LULUS
    return ThreatVerdict.allow(score, entropy: entropy, variance: variance);
  }

  // --- ALGORITMA MATEMATIK (FORENSIK) ---

  double _calculateEntropy(List<MotionEvent> history) {
    if (history.isEmpty) return 0.0;
    
    final mags = history.map((e) => e.magnitude).toList();
    final freq = <int, int>{};
    
    // Binning data untuk histogram
    for (var m in mags) {
      final bucket = (m * 10).floor().clamp(0, 15);
      freq[bucket] = (freq[bucket] ?? 0) + 1;
    }

    double entropy = 0.0;
    for (var count in freq.values) {
      final p = count / mags.length;
      if (p > 0) entropy -= p * log(p) / ln2;
    }

    // Normalize (0.0 - 1.0)
    return (entropy / 3.0).clamp(0.0, 1.0);
  }

  double _calculateVariance(List<MotionEvent> history) {
    if (history.length < 2) return 0.0;
    
    double sum = 0.0;
    double sumSq = 0.0;
    
    for (var h in history) {
      sum += h.magnitude;
      sumSq += h.magnitude * h.magnitude;
    }
    
    final mean = sum / history.length;
    final variance = (sumSq / history.length) - (mean * mean);
    
    return variance.clamp(0.0, 1.0);
  }
}
