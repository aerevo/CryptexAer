/*
 * PROJECT: Z-KINETIC SECURITY CORE
 * MODULE: Behavioral Pattern Analyzer
 * PURPOSE: Advanced biometric intelligence for bot/human detection
 * 
 * VALUE PROPOSITION:
 * - Detect sophisticated bots (not just simple automation)
 * - Identify account takeover attempts
 * - Build user behavioral baseline
 * - Real-time anomaly detection
 * 
 * FEATURES:
 * 1. Motion Pattern Analysis (tremor, rhythm, hesitation)
 * 2. Touch Dynamics (pressure variance, velocity patterns)
 * 3. Temporal Analysis (typing speed, pauses, consistency)
 * 4. Statistical Fingerprinting (unique behavioral signature)
 */

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'motion_models.dart';

/// Behavioral pattern analysis result
class BehavioralAnalysis {
  // Core metrics
  final double humanLikelihood;      // 0.0-1.0 (1.0 = very human)
  final double botProbability;       // 0.0-1.0 (1.0 = very bot-like)
  final double anomalyScore;         // 0.0-1.0 (1.0 = highly anomalous)
  
  // Pattern details
  final MotionPattern motionPattern;
  final TouchPattern touchPattern;
  final TemporalPattern temporalPattern;
  
  // Behavioral fingerprint (unique signature)
  final BehavioralFingerprint fingerprint;
  
  // Risk assessment
  final ThreatLevel threatLevel;
  final List<String> suspiciousIndicators;
  final List<String> humanIndicators;

  BehavioralAnalysis({
    required this.humanLikelihood,
    required this.botProbability,
    required this.anomalyScore,
    required this.motionPattern,
    required this.touchPattern,
    required this.temporalPattern,
    required this.fingerprint,
    required this.threatLevel,
    required this.suspiciousIndicators,
    required this.humanIndicators,
  });

  bool get isProbablyHuman => humanLikelihood > 0.7;
  bool get isProbablyBot => botProbability > 0.6;
  bool get isAnomalous => anomalyScore > 0.7;

  Map<String, dynamic> toJson() => {
    'human_likelihood': humanLikelihood.toStringAsFixed(3),
    'bot_probability': botProbability.toStringAsFixed(3),
    'anomaly_score': anomalyScore.toStringAsFixed(3),
    'threat_level': threatLevel.name,
    'motion_pattern': motionPattern.toJson(),
    'touch_pattern': touchPattern.toJson(),
    'temporal_pattern': temporalPattern.toJson(),
    'fingerprint': fingerprint.toJson(),
    'suspicious_indicators': suspiciousIndicators,
    'human_indicators': humanIndicators,
  };
}

/// Motion pattern characteristics
class MotionPattern {
  final double tremorFrequency;      // Hz (human: 8-12 Hz)
  final double microMovementRatio;   // Small movements vs large
  final double rhythmConsistency;    // Regularity (bot: high, human: variable)
  final double accelerationProfile;  // Smooth vs jerky
  final double directionChanges;     // Randomness in direction

  MotionPattern({
    required this.tremorFrequency,
    required this.microMovementRatio,
    required this.rhythmConsistency,
    required this.accelerationProfile,
    required this.directionChanges,
  });

  Map<String, dynamic> toJson() => {
    'tremor_hz': tremorFrequency.toStringAsFixed(2),
    'micro_movement_ratio': microMovementRatio.toStringAsFixed(3),
    'rhythm_consistency': rhythmConsistency.toStringAsFixed(3),
    'acceleration_profile': accelerationProfile.toStringAsFixed(3),
    'direction_changes': directionChanges.toStringAsFixed(3),
  };
}

/// Touch pattern characteristics
class TouchPattern {
  final double pressureVariance;     // Variance in touch pressure
  final double velocityProfile;      // Speed pattern
  final double hesitationCount;      // Pauses during interaction
  final double coordinationScore;    // Hand-eye coordination

  TouchPattern({
    required this.pressureVariance,
    required this.velocityProfile,
    required this.hesitationCount,
    required this.coordinationScore,
  });

  Map<String, dynamic> toJson() => {
    'pressure_variance': pressureVariance.toStringAsFixed(3),
    'velocity_profile': velocityProfile.toStringAsFixed(3),
    'hesitation_count': hesitationCount.toStringAsFixed(0),
    'coordination_score': coordinationScore.toStringAsFixed(3),
  };
}

/// Temporal pattern characteristics
class TemporalPattern {
  final double averageInteractionTime; // ms
  final double speedVariability;       // Consistency
  final double pauseFrequency;         // Number of pauses
  final double burstiness;             // Activity clustering

  TemporalPattern({
    required this.averageInteractionTime,
    required this.speedVariability,
    required this.pauseFrequency,
    required this.burstiness,
  });

  Map<String, dynamic> toJson() => {
    'avg_interaction_ms': averageInteractionTime.toStringAsFixed(0),
    'speed_variability': speedVariability.toStringAsFixed(3),
    'pause_frequency': pauseFrequency.toStringAsFixed(3),
    'burstiness': burstiness.toStringAsFixed(3),
  };
}

/// Unique behavioral fingerprint
class BehavioralFingerprint {
  final String signatureHash;
  final Map<String, double> features;
  
  BehavioralFingerprint({
    required this.signatureHash,
    required this.features,
  });

  Map<String, dynamic> toJson() => {
    'signature': signatureHash,
    'features': features,
  };
}

/// Behavioral pattern analyzer
class BehavioralAnalyzer {
  // Known human baselines (from research)
  static const double HUMAN_TREMOR_MIN = 8.0;  // Hz
  static const double HUMAN_TREMOR_MAX = 12.0; // Hz
  static const double HUMAN_RHYTHM_VARIANCE = 0.15; // 15% variation
  static const double BOT_RHYTHM_VARIANCE = 0.03;   // 3% variation (too consistent)

  /// Analyze biometric session for behavioral patterns
  BehavioralAnalysis analyze(BiometricSession session) {
    // 1. Analyze motion patterns
    final motionPattern = _analyzeMotionPattern(session.motionEvents);
    
    // 2. Analyze touch patterns
    final touchPattern = _analyzeTouchPattern(session.touchEvents);
    
    // 3. Analyze temporal patterns
    final temporalPattern = _analyzeTemporalPattern(session);
    
    // 4. Calculate scores
    final humanLikelihood = _calculateHumanLikelihood(
      motionPattern,
      touchPattern,
      temporalPattern,
    );
    
    final botProbability = _calculateBotProbability(
      motionPattern,
      touchPattern,
      temporalPattern,
    );
    
    final anomalyScore = _calculateAnomalyScore(
      motionPattern,
      touchPattern,
      temporalPattern,
    );
    
    // 5. Generate behavioral fingerprint
    final fingerprint = _generateFingerprint(
      motionPattern,
      touchPattern,
      temporalPattern,
    );
    
    // 6. Identify indicators
    final suspiciousIndicators = _findSuspiciousIndicators(
      motionPattern,
      touchPattern,
      temporalPattern,
    );
    
    final humanIndicators = _findHumanIndicators(
      motionPattern,
      touchPattern,
      temporalPattern,
    );
    
    // 7. Assess threat level
    final threatLevel = _assessThreatLevel(
      humanLikelihood,
      botProbability,
      anomalyScore,
    );

    return BehavioralAnalysis(
      humanLikelihood: humanLikelihood,
      botProbability: botProbability,
      anomalyScore: anomalyScore,
      motionPattern: motionPattern,
      touchPattern: touchPattern,
      temporalPattern: temporalPattern,
      fingerprint: fingerprint,
      threatLevel: threatLevel,
      suspiciousIndicators: suspiciousIndicators,
      humanIndicators: humanIndicators,
    );
  }

  /// Analyze motion pattern characteristics
  MotionPattern _analyzeMotionPattern(List<MotionEvent> events) {
    if (events.isEmpty) {
      return MotionPattern(
        tremorFrequency: 0,
        microMovementRatio: 0,
        rhythmConsistency: 0,
        accelerationProfile: 0,
        directionChanges: 0,
      );
    }

    // 1. Calculate tremor frequency (physiological tremor: 8-12 Hz)
    final tremorFrequency = _calculateTremorFrequency(events);
    
    // 2. Micro-movement ratio (human: lots of tiny adjustments)
    final microMovementRatio = _calculateMicroMovementRatio(events);
    
    // 3. Rhythm consistency (human: variable, bot: consistent)
    final rhythmConsistency = _calculateRhythmConsistency(events);
    
    // 4. Acceleration profile (human: smooth curves, bot: linear)
    final accelerationProfile = _calculateAccelerationProfile(events);
    
    // 5. Direction changes (human: chaotic, bot: predictable)
    final directionChanges = _calculateDirectionChanges(events);

    return MotionPattern(
      tremorFrequency: tremorFrequency,
      microMovementRatio: microMovementRatio,
      rhythmConsistency: rhythmConsistency,
      accelerationProfile: accelerationProfile,
      directionChanges: directionChanges,
    );
  }

  double _calculateTremorFrequency(List<MotionEvent> events) {
    if (events.length < 5) return 0;

    // Calculate frequency of micro-oscillations
    int oscillations = 0;
    double lastMagnitude = events.first.magnitude;
    bool wasIncreasing = false;

    for (int i = 1; i < events.length; i++) {
      final current = events[i].magnitude;
      final isIncreasing = current > lastMagnitude;
      
      if (isIncreasing != wasIncreasing) {
        oscillations++;
      }
      
      wasIncreasing = isIncreasing;
      lastMagnitude = current;
    }

    final durationSeconds = events.last.timestamp
        .difference(events.first.timestamp).inMilliseconds / 1000.0;
    
    return durationSeconds > 0 ? oscillations / durationSeconds : 0;
  }

  double _calculateMicroMovementRatio(List<MotionEvent> events) {
    if (events.isEmpty) return 0;

    // Count small movements (< 0.5 magnitude) vs large movements
    final microMovements = events.where((e) => e.magnitude < 0.5).length;
    return microMovements / events.length;
  }

  double _calculateRhythmConsistency(List<MotionEvent> events) {
    if (events.length < 3) return 0;

    // Calculate variance in time between events
    final intervals = <double>[];
    for (int i = 1; i < events.length; i++) {
      final interval = events[i].timestamp
          .difference(events[i - 1].timestamp).inMilliseconds.toDouble();
      intervals.add(interval);
    }

    if (intervals.isEmpty) return 0;

    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals.map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / intervals.length;
    final stdDev = sqrt(variance);

    // Coefficient of variation (lower = more consistent)
    return mean > 0 ? stdDev / mean : 0;
  }

  double _calculateAccelerationProfile(List<MotionEvent> events) {
    if (events.length < 3) return 0;

    // Calculate smoothness of acceleration changes
    double totalJerk = 0;
    
    for (int i = 2; i < events.length; i++) {
      final accel1 = events[i - 1].magnitude - events[i - 2].magnitude;
      final accel2 = events[i].magnitude - events[i - 1].magnitude;
      final jerk = (accel2 - accel1).abs();
      totalJerk += jerk;
    }

    return events.length > 2 ? totalJerk / (events.length - 2) : 0;
  }

  double _calculateDirectionChanges(List<MotionEvent> events) {
    if (events.length < 3) return 0;

    int directionChanges = 0;
    
    for (int i = 2; i < events.length; i++) {
      final dx1 = events[i - 1].deltaX - events[i - 2].deltaX;
      final dy1 = events[i - 1].deltaY - events[i - 2].deltaY;
      final dx2 = events[i].deltaX - events[i - 1].deltaX;
      final dy2 = events[i].deltaY - events[i - 1].deltaY;
      
      // Check if direction changed significantly
      final angle1 = atan2(dy1, dx1);
      final angle2 = atan2(dy2, dx2);
      final angleDiff = (angle2 - angle1).abs();
      
      if (angleDiff > pi / 4) { // > 45 degrees
        directionChanges++;
      }
    }

    return events.length > 2 ? directionChanges / (events.length - 2) : 0;
  }

  /// Analyze touch pattern characteristics
  TouchPattern _analyzeTouchPattern(List<TouchEvent> events) {
    if (events.isEmpty) {
      return TouchPattern(
        pressureVariance: 0,
        velocityProfile: 0,
        hesitationCount: 0,
        coordinationScore: 0,
      );
    }

    final pressureVariance = _calculatePressureVariance(events);
    final velocityProfile = _calculateVelocityProfile(events);
    final hesitationCount = _calculateHesitationCount(events);
    final coordinationScore = _calculateCoordinationScore(events);

    return TouchPattern(
      pressureVariance: pressureVariance,
      velocityProfile: velocityProfile,
      hesitationCount: hesitationCount,
      coordinationScore: coordinationScore,
    );
  }

  double _calculatePressureVariance(List<TouchEvent> events) {
    if (events.length < 2) return 0;

    final pressures = events.map((e) => e.pressure).toList();
    final mean = pressures.reduce((a, b) => a + b) / pressures.length;
    final variance = pressures.map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / pressures.length;
    
    return sqrt(variance);
  }

  double _calculateVelocityProfile(List<TouchEvent> events) {
    if (events.isEmpty) return 0;

    final velocities = events.map((e) {
      return sqrt(e.velocityX * e.velocityX + e.velocityY * e.velocityY);
    }).toList();

    return velocities.reduce((a, b) => a + b) / velocities.length;
  }

  double _calculateHesitationCount(List<TouchEvent> events) {
    if (events.length < 2) return 0;

    // Count pauses (gaps > 200ms)
    int hesitations = 0;
    for (int i = 1; i < events.length; i++) {
      final gap = events[i].timestamp
          .difference(events[i - 1].timestamp).inMilliseconds;
      if (gap > 200) {
        hesitations++;
      }
    }

    return hesitations.toDouble();
  }

  double _calculateCoordinationScore(List<TouchEvent> events) {
    if (events.length < 3) return 0.5;

    // Measure smoothness of touch velocity changes
    double smoothness = 0;
    for (int i = 2; i < events.length; i++) {
      final v1 = sqrt(pow(events[i-1].velocityX, 2) + pow(events[i-1].velocityY, 2));
      final v2 = sqrt(pow(events[i].velocityX, 2) + pow(events[i].velocityY, 2));
      smoothness += (v2 - v1).abs();
    }

    // Normalize (lower = better coordination)
    final avgChange = events.length > 2 ? smoothness / (events.length - 2) : 0;
    return (1.0 / (1.0 + avgChange)).clamp(0.0, 1.0);
  }

  /// Analyze temporal patterns
  TemporalPattern _analyzeTemporalPattern(BiometricSession session) {
    final avgTime = session.duration.inMilliseconds.toDouble();
    
    final speedVariability = _calculateSpeedVariability(session);
    final pauseFrequency = _calculatePauseFrequency(session);
    final burstiness = _calculateBurstiness(session);

    return TemporalPattern(
      averageInteractionTime: avgTime,
      speedVariability: speedVariability,
      pauseFrequency: pauseFrequency,
      burstiness: burstiness,
    );
  }

  double _calculateSpeedVariability(BiometricSession session) {
    if (session.motionEvents.length < 2) return 0;

    final speeds = <double>[];
    for (int i = 1; i < session.motionEvents.length; i++) {
      final dt = session.motionEvents[i].timestamp
          .difference(session.motionEvents[i - 1].timestamp).inMilliseconds;
      if (dt > 0) {
        speeds.add(1000.0 / dt); // Events per second
      }
    }

    if (speeds.isEmpty) return 0;

    final mean = speeds.reduce((a, b) => a + b) / speeds.length;
    final variance = speeds.map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / speeds.length;
    
    return sqrt(variance) / (mean + 0.001); // Coefficient of variation
  }

  double _calculatePauseFrequency(BiometricSession session) {
    if (session.motionEvents.length < 2) return 0;

    int pauses = 0;
    for (int i = 1; i < session.motionEvents.length; i++) {
      final gap = session.motionEvents[i].timestamp
          .difference(session.motionEvents[i - 1].timestamp).inMilliseconds;
      if (gap > 100) pauses++;
    }

    return pauses / session.duration.inSeconds.toDouble();
  }

  double _calculateBurstiness(BiometricSession session) {
    if (session.motionEvents.length < 10) return 0;

    // Measure clustering of activity
    final totalDuration = session.duration.inMilliseconds.toDouble();
    final chunkSize = totalDuration / 5; // Divide into 5 chunks
    
    final chunksActivity = List.filled(5, 0);
    for (final event in session.motionEvents) {
      final elapsed = event.timestamp.difference(session.startTime).inMilliseconds;
      final chunkIndex = (elapsed / chunkSize).floor().clamp(0, 4);
      chunksActivity[chunkIndex]++;
    }

    // Calculate variance in activity distribution
    final mean = session.motionEvents.length / 5.0;
    final variance = chunksActivity.map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / 5.0;
    
    return sqrt(variance) / (mean + 0.001);
  }

  /// Calculate human likelihood score
  double _calculateHumanLikelihood(
    MotionPattern motion,
    TouchPattern touch,
    TemporalPattern temporal,
  ) {
    double score = 0;
    int factors = 0;

    // Tremor frequency in human range
    if (motion.tremorFrequency >= HUMAN_TREMOR_MIN && 
        motion.tremorFrequency <= HUMAN_TREMOR_MAX) {
      score += 0.3;
      factors++;
    }

    // High micro-movement ratio (human characteristic)
    if (motion.microMovementRatio > 0.3) {
      score += 0.2;
      factors++;
    }

    // Variable rhythm (not too consistent)
    if (motion.rhythmConsistency > HUMAN_RHYTHM_VARIANCE) {
      score += 0.2;
      factors++;
    }

    // Pressure variance (humans vary pressure)
    if (touch.pressureVariance > 0.1) {
      score += 0.15;
      factors++;
    }

    // Hesitations present (humans pause to think)
    if (touch.hesitationCount > 0) {
      score += 0.15;
      factors++;
    }

    return factors > 0 ? score : 0;
  }

  /// Calculate bot probability score
  double _calculateBotProbability(
    MotionPattern motion,
    TouchPattern touch,
    TemporalPattern temporal,
  ) {
    double score = 0;

    // Too consistent rhythm (bot signature)
    if (motion.rhythmConsistency < BOT_RHYTHM_VARIANCE) {
      score += 0.4;
    }

    // No tremor or out of human range
    if (motion.tremorFrequency < HUMAN_TREMOR_MIN || 
        motion.tremorFrequency > HUMAN_TREMOR_MAX * 1.5) {
      score += 0.3;
    }

    // Perfect pressure (no variance)
    if (touch.pressureVariance < 0.05) {
      score += 0.2;
    }

    // No hesitations (too fast/perfect)
    if (touch.hesitationCount == 0 && temporal.averageInteractionTime < 500) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Calculate anomaly score
  double _calculateAnomalyScore(
    MotionPattern motion,
    TouchPattern touch,
    TemporalPattern temporal,
  ) {
    // Detect unusual patterns (not necessarily bot, but abnormal)
    double anomaly = 0;

    // Extremely high or low values
    if (motion.tremorFrequency > 20 || motion.tremorFrequency < 2) {
      anomaly += 0.3;
    }

    if (temporal.burstiness > 2.0) {
      anomaly += 0.2;
    }

    if (touch.coordinationScore < 0.2) {
      anomaly += 0.2;
    }

    if (temporal.speedVariability > 3.0) {
      anomaly += 0.3;
    }

    return anomaly.clamp(0.0, 1.0);
  }

  /// Generate unique behavioral fingerprint
  BehavioralFingerprint _generateFingerprint(
    MotionPattern motion,
    TouchPattern touch,
    TemporalPattern temporal,
  ) {
    final features = {
      'tremor_freq': motion.tremorFrequency,
      'micro_ratio': motion.microMovementRatio,
      'rhythm_consistency': motion.rhythmConsistency,
      'pressure_var': touch.pressureVariance,
      'coordination': touch.coordinationScore,
      'speed_var': temporal.speedVariability,
      'burstiness': temporal.burstiness,
    };

    // Generate hash from features
    final signature = features.entries
        .map((e) => '${e.key}:${e.value.toStringAsFixed(4)}')
        .join('|');
    
    final hash = signature.hashCode.abs().toRadixString(16).toUpperCase();

    return BehavioralFingerprint(
      signatureHash: 'BEHAVIOR_$hash',
      features: features,
    );
  }

  /// Find suspicious indicators
  List<String> _findSuspiciousIndicators(
    MotionPattern motion,
    TouchPattern touch,
    TemporalPattern temporal,
  ) {
    final indicators = <String>[];

    if (motion.rhythmConsistency < BOT_RHYTHM_VARIANCE) {
      indicators.add('MECHANICAL_RHYTHM');
    }

    if (motion.tremorFrequency < HUMAN_TREMOR_MIN) {
      indicators.add('NO_PHYSIOLOGICAL_TREMOR');
    }

    if (touch.pressureVariance < 0.05) {
      indicators.add('CONSTANT_PRESSURE');
    }

    if (touch.hesitationCount == 0 && temporal.averageInteractionTime < 500) {
      indicators.add('INHUMAN_SPEED');
    }

    if (motion.directionChanges < 0.1) {
      indicators.add('LINEAR_MOVEMENT');
    }

    return indicators;
  }

  /// Find human indicators
  List<String> _findHumanIndicators(
    MotionPattern motion,
    TouchPattern touch,
    TemporalPattern temporal,
  ) {
    final indicators = <String>[];

    if (motion.tremorFrequency >= HUMAN_TREMOR_MIN && 
        motion.tremorFrequency <= HUMAN_TREMOR_MAX) {
      indicators.add('NATURAL_TREMOR');
    }

    if (motion.microMovementRatio > 0.3) {
      indicators.add('MICRO_CORRECTIONS');
    }

    if (touch.pressureVariance > 0.1) {
      indicators.add('VARIABLE_PRESSURE');
    }

    if (touch.hesitationCount > 0) {
      indicators.add('COGNITIVE_PAUSES');
    }

    if (motion.directionChanges > 0.3) {
      indicators.add('ORGANIC_MOVEMENT');
    }

    return indicators;
  }

  /// Assess overall threat level
  ThreatLevel _assessThreatLevel(
    double humanLikelihood,
    double botProbability,
    double anomalyScore,
  ) {
    if (botProbability > 0.7) {
      return ThreatLevel.CRITICAL;
    }

    if (anomalyScore > 0.8) {
      return ThreatLevel.HIGH_RISK;
    }

    if (humanLikelihood < 0.3) {
      return ThreatLevel.SUSPICIOUS;
    }

    return ThreatLevel.SAFE;
  }
}
