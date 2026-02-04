/*
 * PROJECT: Z-KINETIC SECURITY CORE
 * MODULE: Adaptive Threshold Engine
 * PURPOSE: Learn from user behavior and adapt security thresholds
 * VERSION: Production Ready (Cleaned)
 * 
 * VALUE PROPOSITION:
 * - Reduce false positives over time
 * - Detect account takeover (sudden behavior change)
 * - Personalized security (each user has unique baseline)
 * - Machine learning ready (feature extraction for ML models)
 * 
 * FEATURES:
 * 1. User Baseline Learning (normal behavior profile)
 * 2. Adaptive Thresholds (adjust based on history)
 * 3. Anomaly Detection (detect deviations from baseline)
 * 4. Confidence Scoring (how confident we are in decision)
 */

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'behavioral_analyzer.dart';
import 'motion_models.dart';

/// User behavioral baseline (learned over time)
class UserBaseline {
  final String userId;
  final DateTime createdAt;
  final DateTime lastUpdated;
  
  // Statistical baselines
  final double avgTremorFrequency;
  final double avgPressureVariance;
  final double avgInteractionTime;
  final double avgRhythmConsistency;
  
  // Variance (for anomaly detection)
  final double tremorFreqStdDev;
  final double pressureStdDev;
  final double timeStdDev;
  final double rhythmStdDev;
  
  // Learning metrics
  final int sampleCount;
  final double confidenceLevel; // 0.0-1.0 (how confident we are)
  
  UserBaseline({
    required this.userId,
    required this.createdAt,
    required this.lastUpdated,
    required this.avgTremorFrequency,
    required this.avgPressureVariance,
    required this.avgInteractionTime,
    required this.avgRhythmConsistency,
    required this.tremorFreqStdDev,
    required this.pressureStdDev,
    required this.timeStdDev,
    required this.rhythmStdDev,
    required this.sampleCount,
    required this.confidenceLevel,
  });

  bool get isEstablished => sampleCount >= 10 && confidenceLevel > 0.7;
  bool get needsMoreData => sampleCount < 30;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
    'last_updated': lastUpdated.toIso8601String(),
    'avg_tremor_freq': avgTremorFrequency,
    'avg_pressure_var': avgPressureVariance,
    'avg_interaction_time': avgInteractionTime,
    'avg_rhythm_consistency': avgRhythmConsistency,
    'tremor_stddev': tremorFreqStdDev,
    'pressure_stddev': pressureStdDev,
    'time_stddev': timeStdDev,
    'rhythm_stddev': rhythmStdDev,
    'sample_count': sampleCount,
    'confidence': confidenceLevel,
  };

  factory UserBaseline.fromJson(Map<String, dynamic> json) {
    return UserBaseline(
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      lastUpdated: DateTime.parse(json['last_updated']),
      avgTremorFrequency: json['avg_tremor_freq'],
      avgPressureVariance: json['avg_pressure_var'],
      avgInteractionTime: json['avg_interaction_time'],
      avgRhythmConsistency: json['avg_rhythm_consistency'],
      tremorFreqStdDev: json['tremor_stddev'],
      pressureStdDev: json['pressure_stddev'],
      timeStdDev: json['time_stddev'],
      rhythmStdDev: json['rhythm_stddev'],
      sampleCount: json['sample_count'],
      confidenceLevel: json['confidence'],
    );
  }

  /// Create initial baseline (first use)
  factory UserBaseline.initial(String userId) {
    return UserBaseline(
      userId: userId,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      avgTremorFrequency: 0,
      avgPressureVariance: 0,
      avgInteractionTime: 0,
      avgRhythmConsistency: 0,
      tremorFreqStdDev: 0,
      pressureStdDev: 0,
      timeStdDev: 0,
      rhythmStdDev: 0,
      sampleCount: 0,
      confidenceLevel: 0,
    );
  }
}

/// Anomaly detection result
class AnomalyDetectionResult {
  final bool isAnomalous;
  final double anomalyScore;      // 0.0-1.0 (1.0 = very anomalous)
  final double confidenceScore;   // 0.0-1.0 (1.0 = very confident)
  final List<String> deviations;  // What deviated from baseline
  final String verdict;           // NORMAL, SUSPICIOUS, CRITICAL

  AnomalyDetectionResult({
    required this.isAnomalous,
    required this.anomalyScore,
    required this.confidenceScore,
    required this.deviations,
    required this.verdict,
  });

  Map<String, dynamic> toJson() => {
    'is_anomalous': isAnomalous,
    'anomaly_score': anomalyScore.toStringAsFixed(3),
    'confidence_score': confidenceScore.toStringAsFixed(3),
    'deviations': deviations,
    'verdict': verdict,
  };
}

/// Adaptive threshold engine
class AdaptiveThresholdEngine {
  final BehavioralAnalyzer _analyzer = BehavioralAnalyzer();
  
  // Configuration
  final double learningRate;       // How fast to adapt (0.1 = slow, 0.5 = fast)
  final int minSamplesForBaseline; // Minimum samples before trusting baseline
  final double anomalyThreshold;   // Score above which is anomalous
  
  AdaptiveThresholdEngine({
    this.learningRate = 0.2,
    this.minSamplesForBaseline = 10,
    this.anomalyThreshold = 2.5, // 2.5 standard deviations
  });

  /// Analyze session and detect anomalies against user baseline
  AnomalyDetectionResult detectAnomaly({
    required BiometricSession session,
    required UserBaseline? baseline,
  }) {
    // Analyze current behavior
    final analysis = _analyzer.analyze(session);

    // If no baseline, can't detect anomalies yet
    if (baseline == null || !baseline.isEstablished) {
      return AnomalyDetectionResult(
        isAnomalous: false,
        anomalyScore: 0,
        confidenceScore: 0,
        deviations: [],
        verdict: 'INSUFFICIENT_DATA',
      );
    }

    // Compare against baseline
    final deviations = <String>[];
    double totalDeviation = 0;
    int metricCount = 0;

    // 1. Check tremor frequency
    final tremorDev = _calculateZScore(
      analysis.motionPattern.tremorFrequency,
      baseline.avgTremorFrequency,
      baseline.tremorFreqStdDev,
    );
    if (tremorDev.abs() > anomalyThreshold) {
      deviations.add('TREMOR_FREQUENCY_ANOMALY');
      totalDeviation += tremorDev.abs();
    }
    metricCount++;

    // 2. Check pressure variance
    final pressureDev = _calculateZScore(
      analysis.touchPattern.pressureVariance,
      baseline.avgPressureVariance,
      baseline.pressureStdDev,
    );
    if (pressureDev.abs() > anomalyThreshold) {
      deviations.add('PRESSURE_PATTERN_ANOMALY');
      totalDeviation += pressureDev.abs();
    }
    metricCount++;

    // 3. Check interaction time
    final timeDev = _calculateZScore(
      analysis.temporalPattern.averageInteractionTime,
      baseline.avgInteractionTime,
      baseline.timeStdDev,
    );
    if (timeDev.abs() > anomalyThreshold) {
      deviations.add('TIMING_ANOMALY');
      totalDeviation += timeDev.abs();
    }
    metricCount++;

    // 4. Check rhythm consistency
    final rhythmDev = _calculateZScore(
      analysis.motionPattern.rhythmConsistency,
      baseline.avgRhythmConsistency,
      baseline.rhythmStdDev,
    );
    if (rhythmDev.abs() > anomalyThreshold) {
      deviations.add('RHYTHM_ANOMALY');
      totalDeviation += rhythmDev.abs();
    }
    metricCount++;

    // Calculate anomaly score (normalized)
    final anomalyScore = (totalDeviation / metricCount).clamp(0.0, 10.0) / 10.0;

    // Determine verdict
    final verdict = _determineVerdict(anomalyScore, deviations);

    return AnomalyDetectionResult(
      isAnomalous: deviations.isNotEmpty,
      anomalyScore: anomalyScore,
      confidenceScore: baseline.confidenceLevel,
      deviations: deviations,
      verdict: verdict,
    );
  }

  /// Update user baseline with new session data (incremental learning)
  UserBaseline updateBaseline({
    required UserBaseline baseline,
    required BiometricSession session,
  }) {
    final analysis = _analyzer.analyze(session);

    // Incremental mean update (Welford's algorithm)
    final newCount = baseline.sampleCount + 1;
    
    // Update averages
    final newAvgTremor = _updateMean(
      baseline.avgTremorFrequency,
      analysis.motionPattern.tremorFrequency,
      baseline.sampleCount,
    );

    final newAvgPressure = _updateMean(
      baseline.avgPressureVariance,
      analysis.touchPattern.pressureVariance,
      baseline.sampleCount,
    );

    final newAvgTime = _updateMean(
      baseline.avgInteractionTime,
      analysis.temporalPattern.averageInteractionTime,
      baseline.sampleCount,
    );

    final newAvgRhythm = _updateMean(
      baseline.avgRhythmConsistency,
      analysis.motionPattern.rhythmConsistency,
      baseline.sampleCount,
    );

    // Update standard deviations
    final newTremorStdDev = _updateStdDev(
      baseline.tremorFreqStdDev,
      baseline.avgTremorFrequency,
      newAvgTremor,
      analysis.motionPattern.tremorFrequency,
      baseline.sampleCount,
    );

    final newPressureStdDev = _updateStdDev(
      baseline.pressureStdDev,
      baseline.avgPressureVariance,
      newAvgPressure,
      analysis.touchPattern.pressureVariance,
      baseline.sampleCount,
    );

    final newTimeStdDev = _updateStdDev(
      baseline.timeStdDev,
      baseline.avgInteractionTime,
      newAvgTime,
      analysis.temporalPattern.averageInteractionTime,
      baseline.sampleCount,
    );

    final newRhythmStdDev = _updateStdDev(
      baseline.rhythmStdDev,
      baseline.avgRhythmConsistency,
      newAvgRhythm,
      analysis.motionPattern.rhythmConsistency,
      baseline.sampleCount,
    );

    // Update confidence (increases with more samples, caps at 1.0)
    final newConfidence = (newCount / (newCount + 20.0)).clamp(0.0, 1.0);

    return UserBaseline(
      userId: baseline.userId,
      createdAt: baseline.createdAt,
      lastUpdated: DateTime.now(),
      avgTremorFrequency: newAvgTremor,
      avgPressureVariance: newAvgPressure,
      avgInteractionTime: newAvgTime,
      avgRhythmConsistency: newAvgRhythm,
      tremorFreqStdDev: newTremorStdDev,
      pressureStdDev: newPressureStdDev,
      timeStdDev: newTimeStdDev,
      rhythmStdDev: newRhythmStdDev,
      sampleCount: newCount,
      confidenceLevel: newConfidence,
    );
  }

  /// Calculate z-score (how many standard deviations from mean)
  double _calculateZScore(double value, double mean, double stdDev) {
    if (stdDev == 0) return 0;
    return (value - mean) / stdDev;
  }

  /// Update running mean
  double _updateMean(double oldMean, double newValue, int oldCount) {
    if (oldCount == 0) return newValue;
    return oldMean + (newValue - oldMean) / (oldCount + 1);
  }

  /// Update running standard deviation (Welford's algorithm)
  double _updateStdDev(
    double oldStdDev,
    double oldMean,
    double newMean,
    double newValue,
    int oldCount,
  ) {
    if (oldCount == 0) return 0;
    
    final oldVariance = oldStdDev * oldStdDev;
    final oldSum = oldVariance * oldCount;
    
    final newSum = oldSum + (newValue - oldMean) * (newValue - newMean);
    final newVariance = newSum / (oldCount + 1);
    
    return sqrt(newVariance);
  }

  /// Determine verdict based on anomaly score
  String _determineVerdict(double anomalyScore, List<String> deviations) {
    if (deviations.isEmpty) {
      return 'NORMAL';
    }

    if (anomalyScore > 0.8 || deviations.length >= 3) {
      return 'CRITICAL_ANOMALY';
    }

    if (anomalyScore > 0.5 || deviations.length >= 2) {
      return 'SUSPICIOUS_DEVIATION';
    }

    return 'MINOR_DEVIATION';
  }

  /// Get adaptive thresholds for this user (personalized)
  Map<String, double> getAdaptiveThresholds(UserBaseline baseline) {
    if (!baseline.isEstablished) {
      // Return default thresholds if baseline not established
      return {
        'min_tremor_freq': 8.0,
        'max_tremor_freq': 12.0,
        'min_pressure_var': 0.05,
        'max_interaction_time': 5000,
      };
    }

    // Calculate personalized thresholds (mean ± 2 std deviations)
    return {
      'min_tremor_freq': baseline.avgTremorFrequency - (2 * baseline.tremorFreqStdDev),
      'max_tremor_freq': baseline.avgTremorFrequency + (2 * baseline.tremorFreqStdDev),
      'min_pressure_var': (baseline.avgPressureVariance - (2 * baseline.pressureStdDev)).clamp(0.0, 1.0),
      'max_pressure_var': baseline.avgPressureVariance + (2 * baseline.pressureStdDev),
      'min_interaction_time': (baseline.avgInteractionTime - (2 * baseline.timeStdDev)).clamp(100.0, double.infinity),
      'max_interaction_time': baseline.avgInteractionTime + (2 * baseline.timeStdDev),
    };
  }

  /// Export features for machine learning
  Map<String, double> extractMLFeatures({
    required BiometricSession session,
    required UserBaseline? baseline,
  }) {
    final analysis = _analyzer.analyze(session);
    
    final features = <String, double>{
      // Raw features
      'tremor_frequency': analysis.motionPattern.tremorFrequency,
      'micro_movement_ratio': analysis.motionPattern.microMovementRatio,
      'rhythm_consistency': analysis.motionPattern.rhythmConsistency,
      'acceleration_profile': analysis.motionPattern.accelerationProfile,
      'direction_changes': analysis.motionPattern.directionChanges,
      'pressure_variance': analysis.touchPattern.pressureVariance,
      'velocity_profile': analysis.touchPattern.velocityProfile,
      'hesitation_count': analysis.touchPattern.hesitationCount,
      'coordination_score': analysis.touchPattern.coordinationScore,
      'avg_interaction_time': analysis.temporalPattern.averageInteractionTime,
      'speed_variability': analysis.temporalPattern.speedVariability,
      'pause_frequency': analysis.temporalPattern.pauseFrequency,
      'burstiness': analysis.temporalPattern.burstiness,
      
      // Derived features
      'human_likelihood': analysis.humanLikelihood,
      'bot_probability': analysis.botProbability,
      'anomaly_score': analysis.anomalyScore,
    };

    // Add baseline deviation features if available
    if (baseline != null && baseline.isEstablished) {
      features['tremor_z_score'] = _calculateZScore(
        analysis.motionPattern.tremorFrequency,
        baseline.avgTremorFrequency,
        baseline.tremorFreqStdDev,
      );
      
      features['pressure_z_score'] = _calculateZScore(
        analysis.touchPattern.pressureVariance,
        baseline.avgPressureVariance,
        baseline.pressureStdDev,
      );
      
      features['baseline_confidence'] = baseline.confidenceLevel;
      features['baseline_sample_count'] = baseline.sampleCount.toDouble();
    }

    return features;
  }
}
