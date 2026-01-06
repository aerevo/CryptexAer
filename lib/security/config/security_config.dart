/*
 * PROJECT: CryptexLock Security Suite
 * MODULE: Security Configuration
 * PURPOSE: Server validation settings
 */

class SecurityConfig {
  /// Enable server-side validation (Q1: Answer A - Optional, default OFF)
  final bool enableServerValidation;
  
  /// Server endpoint URL
  final String? serverEndpoint;
  
  /// Request timeout
  final Duration serverTimeout;
  
  /// Enable offline fallback (Q2: Answer A - Allow offline)
  final bool allowOfflineFallback;
  
  /// Minimum server confidence threshold (0.0-1.0)
  final double serverConfidenceThreshold;
  
  /// Enable certificate pinning (production security)
  final bool enableCertificatePinning;
  
  const SecurityConfig({
    this.enableServerValidation = false,  // Default OFF
    this.serverEndpoint,
    this.serverTimeout = const Duration(seconds: 5),
    this.allowOfflineFallback = true,     // Default allow offline
    this.serverConfidenceThreshold = 0.85,
    this.enableCertificatePinning = false,
  });
  
  /// Development config (no server validation)
  factory SecurityConfig.development() {
    return const SecurityConfig(
      enableServerValidation: false,
    );
  }
  
  /// Production config (with server validation)
  factory SecurityConfig.production({
    required String serverEndpoint,
  }) {
    return SecurityConfig(
      enableServerValidation: true,
      serverEndpoint: serverEndpoint,
      allowOfflineFallback: true,
      serverConfidenceThreshold: 0.85,
      enableCertificatePinning: true,
    );
  }
  
  /// Strict production (no offline fallback)
  factory SecurityConfig.strict({
    required String serverEndpoint,
  }) {
    return SecurityConfig(
      enableServerValidation: true,
      serverEndpoint: serverEndpoint,
      allowOfflineFallback: false,  // No fallback!
      serverConfidenceThreshold: 0.90,
      enableCertificatePinning: true,
    );
  }
  
  /// Validate configuration
  bool isValid() {
    if (enableServerValidation && (serverEndpoint == null || serverEndpoint!.isEmpty)) {
      return false;
    }
    return true;
  }
}
