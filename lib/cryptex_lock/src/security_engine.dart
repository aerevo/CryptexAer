// 🎯 PROJECT Z-KINETIC V3.0 - SECURITY ENGINE
// Standard: Bank-Grade Security • Logic & Threat Analysis
// Identity: Captain Aer Security Suite
// Author: Francois (Loyal Butler)

import 'dart:math';
import 'cla_models.dart';

/// ═══════════════════════════════════════════════════════════
/// THREAT VERDICT - Keputusan Akhir Engine
/// ═══════════════════════════════════════════════════════════
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

  factory ThreatVerdict.allow({required double confidence}) {
    return ThreatVerdict(
      allowed: true,
      level: ThreatLevel.NONE,
      reason: 'BIOMETRIC_VERIFIED',
      confidence: confidence,
    );
  }

  factory ThreatVerdict.deny({required ThreatLevel level, required String reason}) {
    return ThreatVerdict(
      allowed: false,
      level: level,
      reason: reason,
      confidence: 0.0,
    );
  }
}

enum ThreatLevel { NONE, LOW, MEDIUM, HIGH, CRITICAL }

/// ═══════════════════════════════════════════════════════════
/// SECURITY ENGINE - Otak Pemprosesan (Pure Logic)
/// ═══════════════════════════════════════════════════════════
class SecurityEngine {
  final SecurityEngineConfig config;

  SecurityEngine(this.config);

  /// ANALISIS UTAMA: Bot vs Human Detection
  ThreatVerdict analyze({
    required double motionConfidence,
    required double touchConfidence,
    required List<MotionEvent> motionHistory,
    required int touchCount,
  }) {
    // 1. SEMAKAN KEHADIRAN BIOMETRIK (Presence Check)
    if (motionConfidence < 0.1 && touchConfidence < 0.3) {
      return ThreatVerdict.deny(
        level: ThreatLevel.HIGH,
        reason: 'NO BIO-KINETIC SIGNATURE',
      );
    }

    // 2. ANALISIS CORAK GERAKAN (Entropy & Variance)
    final metrics = _calculateMetrics(motionHistory);
    
    // Semak jika gerakan terlalu statik atau robotik
    if (metrics['entropy'] < config.minEntropy) {
      return ThreatVerdict.deny(
        level: ThreatLevel.MEDIUM,
        reason: 'PATTERN_TOO_LINEAR (BOT_SUSPECTED)',
      );
    }

    // 3. SEMAKAN TREMOR (Human Hand Frequency 8-12Hz)
    final tremorHz = metrics['tremor_hz'] as double;
    if (tremorHz < 7.0 || tremorHz > 14.0) {
      return ThreatVerdict.deny(
        level: ThreatLevel.HIGH,
        reason: 'ABNORMAL_TREMOR_DETECTED',
      );
    }

    // 4. PENGIRAAN SKOR KEYAKINAN (Final Confidence)
    final finalScore = _calculateFinalScore(
      motionConfidence, 
      touchConfidence, 
      metrics['entropy']
    );

    if (finalScore < config.minConfidenceScore) {
      return ThreatVerdict.deny(
        level: ThreatLevel.MEDIUM,
        reason: 'LOW_CONFIDENCE_SCORE',
      );
    }

    // SEMUA UJIAN LEPAS
    return ThreatVerdict.allow(confidence: finalScore);
  }

  // Pengiraan Metrik Fizik (Entropy/Variance/Tremor)
  Map<String, dynamic> _calculateMetrics(List<MotionEvent> history) {
    if (history.isEmpty) return {'entropy': 0.0, 'variance': 0.0, 'tremor_hz': 0.0};

    final magnitudes = history.map((e) => e.magnitude).toList();
    
    // Variance
    final mean = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
    final variance = magnitudes.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / magnitudes.length;

    // Shannon Entropy (Kekalisan Corak)
    final freq = <int, int>{};
    for (var m in magnitudes) {
      final bucket = (m * 10).toInt();
      freq[bucket] = (freq[bucket] ?? 0) + 1;
    }
    double entropy = 0.0;
    for (var count in freq.values) {
      final p = count / magnitudes.length;
      entropy -= p * log(p) / ln2;
    }

    // Tremor Frequency Estimation
    int microMovements = 0;
    for (int i = 1; i < history.length; i++) {
      final interval = history[i].timestamp.difference(history[i - 1].timestamp).inMilliseconds;
      if (interval > 80 && interval < 125) { // Range 8-12Hz
        microMovements++;
      }
    }
    double tremorHz = (microMovements / history.length) * 10;

    return {
      'entropy': entropy,
      'variance': variance,
      'tremor_hz': tremorHz,
    };
  }

  double _calculateFinalScore(double m, double t, double e) {
    // Berat: 40% Motion, 30% Touch, 30% Entropy
    return (m * 0.4) + (t * 0.3) + ((e / 3.0).clamp(0, 1) * 0.3);
  }
}

/// ═══════════════════════════════════════════════════════════
/// KONFIGURASI ENGINE
/// ═══════════════════════════════════════════════════════════
class SecurityEngineConfig {
  final double minEntropy;
  final double minVariance;
  final double minConfidenceScore;

  const SecurityEngineConfig({
    this.minEntropy = 0.5,
    this.minVariance = 0.05,
    this.minConfidenceScore = 0.7,
  });

  factory SecurityEngineConfig.strict() => const SecurityEngineConfig(
    minEntropy: 0.7,
    minVariance: 0.1,
    minConfidenceScore: 0.85,
  );
}
