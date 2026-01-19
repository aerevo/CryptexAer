// test/ai_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app_name/cryptex_lock/src/adaptive_threshold_engine.dart';
import 'package:your_app_name/cryptex_lock/src/behavioral_analyzer.dart';
import 'package:your_app_name/cryptex_lock/src/motion_models.dart';

void main() {
  group('🧠 Adaptive Threshold Engine', () {
    late AdaptiveThresholdEngine engine;
    late UserBaseline baseline;

    setUp(() {
      engine = AdaptiveThresholdEngine();
      baseline = UserBaseline(
        userId: 'test_user',
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        avgTremorFrequency: 10.0,
        avgPressureVariance: 0.15,
        avgInteractionTime: 2000,
        avgRhythmConsistency: 0.2,
        tremorFreqStdDev: 1.0,
        pressureStdDev: 0.03,
        timeStdDev: 300,
        rhythmStdDev: 0.05,
        sampleCount: 15,
        confidenceLevel: 0.8,
      );
    });

    test('✅ Detects normal behavior', () {
      final session = _createMockSession(
        tremorFreq: 10.0,
        pressureVar: 0.15,
        interactionTime: 2000,
      );

      final result = engine.detectAnomaly(
        session: session,
        baseline: baseline,
      );

      expect(result.isAnomalous, false);
      expect(result.verdict, 'NORMAL');
    });

    test('⚠️ Detects tremor anomaly', () {
      final session = _createMockSession(
        tremorFreq: 20.0, // Way above baseline
        pressureVar: 0.15,
        interactionTime: 2000,
      );

      final result = engine.detectAnomaly(
        session: session,
        baseline: baseline,
      );

      expect(result.isAnomalous, true);
      expect(result.deviations, contains('TREMOR_FREQUENCY_ANOMALY'));
    });

    test('🚨 Detects critical anomaly (multiple deviations)', () {
      final session = _createMockSession(
        tremorFreq: 20.0,
        pressureVar: 0.5, // High
        interactionTime: 5000, // High
      );

      final result = engine.detectAnomaly(
        session: session,
        baseline: baseline,
      );

      expect(result.isAnomalous, true);
      expect(result.anomalyScore, greaterThan(0.5));
      expect(result.verdict, 'CRITICAL_ANOMALY');
    });

    test('📊 Updates baseline correctly', () {
      final session = _createMockSession(
        tremorFreq: 11.0,
        pressureVar: 0.16,
        interactionTime: 2100,
      );

      final updatedBaseline = engine.updateBaseline(
        baseline: baseline,
        session: session,
      );

      expect(updatedBaseline.sampleCount, baseline.sampleCount + 1);
      expect(updatedBaseline.confidenceLevel, greaterThan(baseline.confidenceLevel));
      expect(updatedBaseline.avgTremorFrequency, isNot(baseline.avgTremorFrequency));
    });

    test('🎯 Returns insufficient data for new users', () {
      final newBaseline = UserBaseline.initial('new_user');
      final session = _createMockSession();

      final result = engine.detectAnomaly(
        session: session,
        baseline: newBaseline,
      );

      expect(result.verdict, 'INSUFFICIENT_DATA');
    });

    test('🔧 Generates adaptive thresholds', () {
      final thresholds = engine.getAdaptiveThresholds(baseline);

      expect(thresholds['min_tremor_freq'], lessThan(baseline.avgTremorFrequency));
      expect(thresholds['max_tremor_freq'], greaterThan(baseline.avgTremorFrequency));
      expect(thresholds['min_pressure_var'], greaterThanOrEqualTo(0));
    });
  });

  group('🤖 Behavioral Analyzer', () {
    late BehavioralAnalyzer analyzer;

    setUp(() {
      analyzer = BehavioralAnalyzer();
    });

    test('✅ Analyzes human-like behavior', () {
      final session = _createRealisticHumanSession();
      final analysis = analyzer.analyze(session);

      expect(analysis.humanLikelihood, greaterThan(0.5));
      expect(analysis.botProbability, lessThan(0.5));
      expect(analysis.isProbablyHuman, true);
    });

    test('🤖 Detects bot-like behavior', () {
      final session = _createBotLikeSession();
      final analysis = analyzer.analyze(session);

      expect(analysis.botProbability, greaterThan(0.4));
      expect(analysis.suspiciousIndicators, isNotEmpty);
    });

    test('📊 Calculates motion pattern correctly', () {
      final session = _createMockSession();
      final analysis = analyzer.analyze(session);

      expect(analysis.motionPattern.tremorFrequency, greaterThanOrEqualTo(0));
      expect(analysis.motionPattern.microMovementRatio, inInclusiveRange(0, 1));
    });

    test('🔍 Generates behavioral fingerprint', () {
      final session = _createMockSession();
      final analysis = analyzer.analyze(session);

      expect(analysis.fingerprint.signatureHash, isNotEmpty);
      expect(analysis.fingerprint.features, isNotEmpty);
    });
  });
}

// ============================================
// HELPER FUNCTIONS
// ============================================

BiometricSession _createMockSession({
  double tremorFreq = 10.0,
  double pressureVar = 0.15,
  double interactionTime = 2000,
}) {
  final startTime = DateTime.now();
  
  return BiometricSession(
    sessionId: 'test_session',
    startTime: startTime,
    motionEvents: List.generate(20, (i) {
      return MotionEvent(
        magnitude: 1.0 + (i % 3) * 0.5,
        timestamp: startTime.add(Duration(milliseconds: i * 100)),
        deltaX: 0.1 * i,
        deltaY: 0.1 * i,
        deltaZ: 0.1 * i,
      );
    }),
    touchEvents: List.generate(10, (i) {
      return TouchEvent(
        timestamp: startTime.add(Duration(milliseconds: i * 200)),
        pressure: 0.4 + (i % 3) * 0.1,
      );
    }),
    duration: Duration(milliseconds: interactionTime.toInt()),
  );
}

BiometricSession _createRealisticHumanSession() {
  final startTime = DateTime.now();
  
  // Human-like: variable tremor, inconsistent timing
  return BiometricSession(
    sessionId: 'human_session',
    startTime: startTime,
    motionEvents: List.generate(30, (i) {
      return MotionEvent(
        magnitude: 0.8 + (i % 5) * 0.3, // Variable
        timestamp: startTime.add(Duration(milliseconds: i * (80 + i % 30))), // Inconsistent
        deltaX: 0.1 * (i % 3),
        deltaY: 0.1 * (i % 4),
        deltaZ: 0.1 * (i % 2),
      );
    }),
    touchEvents: List.generate(15, (i) {
      return TouchEvent(
        timestamp: startTime.add(Duration(milliseconds: i * (150 + i % 50))),
        pressure: 0.3 + (i % 4) * 0.15, // Variable pressure
      );
    }),
    duration: Duration(seconds: 3),
  );
}

BiometricSession _createBotLikeSession() {
  final startTime = DateTime.now();
  
  // Bot-like: perfect timing, consistent magnitude
  return BiometricSession(
    sessionId: 'bot_session',
    startTime: startTime,
    motionEvents: List.generate(30, (i) {
      return MotionEvent(
        magnitude: 1.0, // Perfectly consistent
        timestamp: startTime.add(Duration(milliseconds: i * 100)), // Perfect timing
        deltaX: 0.1,
        deltaY: 0.1,
        deltaZ: 0.1,
      );
    }),
    touchEvents: List.generate(15, (i) {
      return TouchEvent(
        timestamp: startTime.add(Duration(milliseconds: i * 200)),
        pressure: 0.5, // No variation
      );
    }),
    duration: Duration(milliseconds: 500), // Too fast
  );
}
