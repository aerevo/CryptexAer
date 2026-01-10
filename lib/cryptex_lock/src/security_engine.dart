// 🔐 PROJECT Z-KINETIC V4.0 — BANK-GRADE SECURITY ENGINE
// Pure Logic • Deterministic • Zero-UI
// Authoritative Rewrite by François (Shadow Mode)

import 'dart:math';
import 'cla_models.dart';

enum ThreatLevel { NONE, LOW, MEDIUM, HIGH, CRITICAL }

class ThreatVerdict {
  final bool allowed;
  final ThreatLevel level;
  final String reason;
  final double confidence;

  const ThreatVerdict({
    required this.allowed,
    required this.level,
    required this.reason,
    required this.confidence,
  });

  factory ThreatVerdict.allow(double confidence) {
    return ThreatVerdict(
      allowed: true,
      level: ThreatLevel.NONE,
      reason: 'HUMAN_SIGNATURE_CONFIRMED',
      confidence: confidence,
    );
  }

  factory ThreatVerdict.deny(ThreatLevel level, String reason) {
    return ThreatVerdict(
      allowed: false,
      level: level,
      reason: reason,
      confidence: 0.0,
    );
  }
}

class SecurityEngineConfig {
  final double minEntropy;
  final double minVariance;
  final double minConfidence;

  const SecurityEngineConfig({
    this.minEntropy = 0.3,
    this.minVariance = 0.02,
    this.minConfidence = 0.5,
  });
}

/// 🧠 Stateful Threat Engine (Bank Grade)
class SecurityEngine {
  final SecurityEngineConfig config;

  // Escalation memory
  double _threatScore = 0.0;

  SecurityEngine(this.config);

  ThreatVerdict analyze({
    required double motionConfidence,
    required double touchConfidence,
    required List<MotionEvent> motionHistory,
    required int touchCount,
  }) {
    // ───────────────────────────────
    // 0. Hard Presence Gate
    // ───────────────────────────────
    if (motionConfidence < 0.1 && touchConfidence < 0.2) {
      _escalate(0.3);
      return ThreatVerdict.deny(
        ThreatLevel.HIGH,
        'NO_HUMAN_PRESENCE',
      );
    }

    // ───────────────────────────────
    // 1. Motion Metrics
    // ───────────────────────────────
    final metrics = _computeMetrics(motionHistory);

    if (metrics.entropy < config.minEntropy) {
      _escalate(0.2);
      return ThreatVerdict.deny(
        ThreatLevel.MEDIUM,
        'LOW_ENTROPY_PATTERN',
      );
    }

    if (metrics.variance < config.minVariance) {
      _escalate(0.25);
      return ThreatVerdict.deny(
        ThreatLevel.HIGH,
        'ROBOTIC_MOTION_VARIANCE',
      );
    }

    if (!_validTremor(metrics.tremorHz)) {
      _escalate(0.35);
      return ThreatVerdict.deny(
        ThreatLevel.CRITICAL,
        'NON_HUMAN_TREMOR_SIGNATURE',
      );
    }

    // ───────────────────────────────
    // 2. Final Confidence
    // ───────────────────────────────
    final confidence = _finalScore(
      motionConfidence,
      touchConfidence,
      metrics.entropy,
    );

    if (confidence < config.minConfidence) {
      _escalate(0.2);
      return ThreatVerdict.deny(
        ThreatLevel.MEDIUM,
        'CONFIDENCE_TOO_LOW',
      );
    }

    // ───────────────────────────────
    // SUCCESS — decay threat memory
    // ───────────────────────────────
    _threatScore = (_threatScore * 0.4).clamp(0.0, 1.0);

    return ThreatVerdict.allow(confidence);
  }

  // ════════════════════════════════════════════════
  // INTERNALS
  // ════════════════════════════════════════════════

  void _escalate(double weight) {
    _threatScore = (_threatScore + weight).clamp(0.0, 1.0);
  }

  bool _validTremor(double hz) {
    // Human physiological tremor range
    return hz >= 5.0 && hz <= 15.0;
  }

  double _finalScore(double m, double t, double e) {
    final entropyNorm = (e / 3.0).clamp(0.0, 1.0);
    final base = (m * 0.4) + (t * 0.35) + (entropyNorm * 0.25);
    return (base - _threatScore * 0.3).clamp(0.0, 1.0);
  }

  _MotionMetrics _computeMetrics(List<MotionEvent> history) {
    if (history.length < 6) {
      return _MotionMetrics.zero();
    }

    final mags = history.map((e) => e.magnitude).toList();
    final mean = mags.reduce((a, b) => a + b) / mags.length;

    final variance = mags
            .map((x) => pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        mags.length;

    // Shannon Entropy
    final freq = <int, int>{};
    for (var m in mags) {
      final bucket = (m * 12).floor();
      freq[bucket] = (freq[bucket] ?? 0) + 1;
    }

    double entropy = 0.0;
    for (var c in freq.values) {
      final p = c / mags.length;
      entropy -= p * log(p) / ln2;
    }

    // Tremor frequency (time-normalized)
    int valid = 0;
    int totalMs = 0;

    for (int i = 1; i < history.length; i++) {
      final dt = history[i]
          .timestamp
          .difference(history[i - 1].timestamp)
          .inMilliseconds;
      if (dt > 0) {
        totalMs += dt;
        if (dt >= 70 && dt <= 140) valid++;
      }
    }

    final seconds = totalMs / 1000.0;
    final hz = seconds > 0 ? valid / seconds : 0.0;

    return _MotionMetrics(
      entropy: entropy,
      variance: variance,
      tremorHz: hz,
    );
  }
}

class _MotionMetrics {
  final double entropy;
  final double variance;
  final double tremorHz;

  _MotionMetrics({
    required this.entropy,
    required this.variance,
    required this.tremorHz,
  });

  factory _MotionMetrics.zero() =>
      _MotionMetrics(entropy: 0, variance: 0, tremorHz: 0);
}
