/*
 * PROJECT: Z-KINETIC SECURITY CORE
 * MODULE: Composite Attestation Provider
 * PURPOSE: Multi-layer attestation (defense in depth)
 * 
 * USAGE:
 * final attestation = CompositeAttestationProvider([
 *   DeviceIntegrityAttestation(),
 *   ServerAttestationProvider(config),
 * ]);
 * 
 * STRATEGIES:
 * - ALL_MUST_PASS: Require all providers to verify (strictest)
 * - ANY_CAN_PASS: Allow if any provider verifies (lenient)
 * - MAJORITY_WINS: Require majority consensus (balanced)
 * - WEIGHTED: Weighted voting based on provider trust
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'security_core.dart';
import 'motion_models.dart';

/// Attestation strategy
enum AttestationStrategy {
  ALL_MUST_PASS,   // All providers must verify (AND logic)
  ANY_CAN_PASS,    // Any provider can verify (OR logic)
  MAJORITY_WINS,   // Majority of providers must verify
  WEIGHTED,        // Weighted voting system
}

/// Provider with weight (for weighted strategy)
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

/// Composite attestation result
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

/// Composite attestation provider (multi-layer)
class CompositeAttestationProvider implements AttestationProvider {
  final List<WeightedProvider> providers;
  final AttestationStrategy strategy;
  final double requiredConfidence;

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
  }).toList();

  /// Constructor for weighted providers
  CompositeAttestationProvider.weighted(
    this.providers, {
    this.strategy = AttestationStrategy.WEIGHTED,
    this.requiredConfidence = 0.7,
  });

  @override
  Future<AttestationResult> attest(ValidationAttempt attempt) async {
    // Run all providers in parallel
    final results = await Future.wait(
      providers.map((wp) => _attestWithTimeout(wp, attempt)),
    );

    // Map results to providers
    final providerResults = <String, AttestationResult>{};
    for (int i = 0; i < providers.length; i++) {
      providerResults[providers[i].name] = results[i];
    }

    // Count passed/failed
    final passedCount = results.where((r) => r.verified).length;
    final failedCount = results.length - passedCount;

    // Evaluate based on strategy
    final verified = _evaluateStrategy(results);

    // Generate composite token
    final token = _generateCompositeToken(providerResults, verified);

    // Calculate expiry (shortest of all providers)
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

  /// Attest with timeout protection
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

  /// Evaluate based on selected strategy
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

  /// Evaluate using weighted voting
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

  /// Generate composite token
  String _generateCompositeToken(
    Map<String, AttestationResult> results,
    bool verified,
  ) {
    if (!verified) return '';

    // Combine tokens from all verified providers
    final verifiedTokens = results.entries
        .where((e) => e.value.verified && e.value.token.isNotEmpty)
        .map((e) => e.value.token)
        .toList();

    if (verifiedTokens.isEmpty) {
      return 'COMPOSITE_${DateTime.now().millisecondsSinceEpoch}';
    }

    // In production, would create signed JWT combining all tokens
    return 'COMPOSITE_${verifiedTokens.first}_MULTI';
  }

  /// Calculate earliest expiry
  DateTime _calculateExpiry(List<AttestationResult> results) {
    final verifiedResults = results.where((r) => r.verified).toList();
    
    if (verifiedResults.isEmpty) {
      return DateTime.now();
    }

    // Use shortest expiry time (most conservative)
    return verifiedResults
        .map((r) => r.expiresAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Aggregate claims from all providers
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

/// Pre-configured composite providers

/// Bank-grade attestation (all must pass)
class BankGradeAttestation extends CompositeAttestationProvider {
  BankGradeAttestation({
    required AttestationProvider deviceIntegrity,
    required AttestationProvider serverAttestation,
  }) : super(
    [deviceIntegrity, serverAttestation],
    strategy: AttestationStrategy.ALL_MUST_PASS,
  );
}

/// Balanced attestation (majority wins)
class BalancedAttestation extends CompositeAttestationProvider {
  BalancedAttestation({
    required AttestationProvider deviceIntegrity,
    required AttestationProvider serverAttestation,
    AttestationProvider? additionalProvider,
  }) : super(
    [
      deviceIntegrity,
      serverAttestation,
      if (additionalProvider != null) additionalProvider,
    ],
    strategy: AttestationStrategy.MAJORITY_WINS,
  );
}

/// Weighted attestation (custom weights)
class WeightedAttestation extends CompositeAttestationProvider {
  WeightedAttestation({
    required AttestationProvider highTrustProvider,
    required AttestationProvider mediumTrustProvider,
    AttestationProvider? lowTrustProvider,
    double requiredConfidence = 0.7,
  }) : super.weighted(
    [
      WeightedProvider(
        provider: highTrustProvider,
        weight: 0.6,
        name: 'HighTrust',
      ),
      WeightedProvider(
        provider: mediumTrustProvider,
        weight: 0.3,
        name: 'MediumTrust',
      ),
      if (lowTrustProvider != null)
        WeightedProvider(
          provider: lowTrustProvider,
          weight: 0.1,
          name: 'LowTrust',
        ),
    ],
    strategy: AttestationStrategy.WEIGHTED,
    requiredConfidence: requiredConfidence,
  );
}
