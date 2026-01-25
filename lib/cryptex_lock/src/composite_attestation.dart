// lib/cryptex_lock/src/composite_attestation.dart (FIXED ✅)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'security_core.dart';
import 'motion_models.dart';

enum AttestationStrategy {
  ALL_MUST_PASS,
  ANY_CAN_PASS,
  MAJORITY_WINS,
  WEIGHTED,
}

class WeightedProvider {
  final AttestationProvider provider;
  final double weight;
  final String name;

  WeightedProvider({
    required this.provider,
    required this.weight,
    required this.name,
  });
}

class CompositeAttestationResult extends AttestationResult {
  final Map<String, AttestationResult> providerResults;
  final int passedCount;
  final int failedCount;
  final AttestationStrategy strategy;

  CompositeAttestationResult({
    required bool verified,
    required String token,
    required DateTime expiresAt,
    required this.providerResults,
    required this.passedCount,
    required this.failedCount,
    required this.strategy,
    Map<String, dynamic> claims = const {},
  }) : super(
    verified: verified,
    token: token,
    expiresAt: expiresAt,
    claims: {
      ...claims,
      'composite': true,
      'strategy': strategy.name,
      'passed': passedCount,
      'failed': failedCount,
      'providers': providerResults.length,
    },
  );
}

// ✅ FIXED: Class name (bukan 'CompositeAttestation')
class CompositeAttestationProvider implements AttestationProvider {
  final List<WeightedProvider> providers;
  final AttestationStrategy strategy;
  final double requiredConfidence;

  /// Constructor with simple providers (equal weight)
  CompositeAttestationProvider(
    List<AttestationProvider> simpleProviders, {
    this.strategy = AttestationStrategy.ALL_MUST_PASS,
    this.requiredConfidence = 0.7,
  }) : providers = simpleProviders.asMap().entries.map((entry) {
    return WeightedProvider(
      provider: entry.value,
      weight: 1.0,
      name: 'Provider_${entry.key}',
    );
  }).toList() {
    if (providers.isEmpty) {
      throw ArgumentError('CompositeAttestationProvider requires at least one provider');
    }
  }

  /// Constructor for weighted providers
  CompositeAttestationProvider.weighted(
    this.providers, {
    this.strategy = AttestationStrategy.WEIGHTED,
    this.requiredConfidence = 0.7,
  });

  @override
  Future<AttestationResult> attest(ValidationAttempt attempt) async {
    final results = await Future.wait(
      providers.map((wp) => _attestWithTimeout(wp, attempt)),
    );

    final providerResults = <String, AttestationResult>{};
    for (int i = 0; i < providers.length; i++) {
      providerResults[providers[i].name] = results[i];
    }

    final passedCount = results.where((r) => r.verified).length;
    final failedCount = results.length - passedCount;

    final verified = _evaluateStrategy(results);

    final token = _generateCompositeToken(providerResults, verified);

    final expiresAt = _calculateExpiry(results);

    return CompositeAttestationResult(
      verified: verified,
      token: token,
      expiresAt: expiresAt,
      providerResults: providerResults,
      passedCount: passedCount,
      failedCount: failedCount,
      strategy: strategy,
      claims: _aggregateClaims(providerResults),
    );
  }

  Future<AttestationResult> _attestWithTimeout(
    WeightedProvider wp,
    ValidationAttempt attempt,
  ) async {
    try {
      return await wp.provider.attest(attempt).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('⚠️ ${wp.name} timed out');
          return AttestationResult(
            verified: false,
            token: '',
            expiresAt: DateTime.now(),
            claims: {'error': 'timeout'},
          );
        },
      );
    } catch (e) {
      if (kDebugMode) print('❌ ${wp.name} failed: $e');
      return AttestationResult(
        verified: false,
        token: '',
        expiresAt: DateTime.now(),
        claims: {'error': e.toString()},
      );
    }
  }

  bool _evaluateStrategy(List<AttestationResult> results) {
    switch (strategy) {
      case AttestationStrategy.ALL_MUST_PASS:
        return results.every((r) => r.verified);

      case AttestationStrategy.ANY_CAN_PASS:
        return results.any((r) => r.verified);

      case AttestationStrategy.MAJORITY_WINS:
        final passedCount = results.where((r) => r.verified).length;
        return passedCount > results.length / 2;

      case AttestationStrategy.WEIGHTED:
        return _evaluateWeighted(results);
    }
  }

  bool _evaluateWeighted(List<AttestationResult> results) {
    double totalWeight = 0.0;
    double passedWeight = 0.0;

    for (int i = 0; i < results.length; i++) {
      final weight = providers[i].weight;
      totalWeight += weight;

      if (results[i].verified) {
        passedWeight += weight;
      }
    }

    final confidence = totalWeight > 0 ? passedWeight / totalWeight : 0.0;

    if (kDebugMode) {
      print('🔍 Weighted confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    }

    return confidence >= requiredConfidence;
  }

  String _generateCompositeToken(
    Map<String, AttestationResult> results,
    bool verified,
  ) {
    if (!verified) return '';

    final verifiedTokens = results.entries
      .where((e) => e.value.verified && e.value.token.isNotEmpty)
      .map((e) => e.value.token)
      .toList();

    if (verifiedTokens.isEmpty) {
      return 'COMPOSITE_${DateTime.now().millisecondsSinceEpoch}';
    }

    return 'COMPOSITE_${verifiedTokens.first}_MULTI';
  }

  DateTime _calculateExpiry(List<AttestationResult> results) {
    final verifiedResults = results.where((r) => r.verified).toList();

    if (verifiedResults.isEmpty) {
      return DateTime.now();
    }

    return verifiedResults
      .map((r) => r.expiresAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  Map<String, dynamic> _aggregateClaims(
    Map<String, AttestationResult> results
  ) {
    final aggregated = <String, dynamic>{};

    for (final entry in results.entries) {
      aggregated[entry.key] = {
        'verified': entry.value.verified,
        'claims': entry.value.claims,
      };
    }

    return aggregated;
  }
}
