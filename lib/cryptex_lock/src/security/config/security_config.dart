/*
 * PROJECT: CryptexLock Security Suite
 * MODULE: Security Configuration (MERGED: Core + Server)
 */

class SecurityConfig {
  // =========================================================
  // 1. CORE SECURITY SETTINGS (Wajib ada untuk elak crash)
  // =========================================================
  final bool enableBiometrics;
  final bool enablePinFallback;
  final int maxAttempts;
  final Duration lockoutDuration;
  final bool vibrateOnTouch;
  final bool obscureInput;

  // =========================================================
  // 2. SERVER VALIDATION SETTINGS
  // =========================================================
  /// Enable server-side validation
  final bool enableServerValidation;
  
  /// Server endpoint URL
  final String serverEndpoint;
  
  /// Request timeout
  final Duration serverTimeout;
  
  /// Enable offline fallback
  final bool allowOfflineFallback;
  
  /// Minimum server confidence threshold (0.0-1.0)
  final double serverConfidenceThreshold;
  
  /// Enable certificate pinning (production security)
  final bool enableCertificatePinning;

  const SecurityConfig({
    // Core Defaults
    this.enableBiometrics = true,
    this.enablePinFallback = true,
    this.maxAttempts = 5,
    this.lockoutDuration = const Duration(seconds: 30),
    this.vibrateOnTouch = true,
    this.obscureInput = false,

    // Server Defaults
    this.enableServerValidation = false,
    this.serverEndpoint = "https://api.cryptex.aer/verify", // Default dummy URL
    this.serverTimeout = const Duration(seconds: 5),
    this.allowOfflineFallback = true,
    this.serverConfidenceThreshold = 0.85,
    this.enableCertificatePinning = false,
  });

  // =========================================================
  // FACTORIES
  // =========================================================

  /// Standard default config
  factory SecurityConfig.standard() {
    return const SecurityConfig();
  }

  /// Development config (no server validation)
  factory SecurityConfig.development() {
    return const SecurityConfig(
      enableServerValidation: false,
      enableBiometrics: true,
    );
  }
  
  /// Production config (High Security + Server)
  factory SecurityConfig.production({
    required String serverEndpoint,
  }) {
    return SecurityConfig(
      enableBiometrics: true,
      maxAttempts: 3,
      lockoutDuration: const Duration(minutes: 5),
      
      enableServerValidation: true,
      serverEndpoint: serverEndpoint,
      allowOfflineFallback: true,
      serverConfidenceThreshold: 0.85,
      enableCertificatePinning: true,
    );
  }
  
  /// Strict production (No offline fallback)
  factory SecurityConfig.strict({
    required String serverEndpoint,
  }) {
    return SecurityConfig(
      enableBiometrics: true,
      maxAttempts: 3,
      obscureInput: true,
      
      enableServerValidation: true,
      serverEndpoint: serverEndpoint,
      allowOfflineFallback: false,
      serverConfidenceThreshold: 0.90,
      enableCertificatePinning: true,
    );
  }
  
  /// Validate configuration integrity
  bool isValid() {
    if (enableServerValidation && serverEndpoint.isEmpty) {
      return false;
    }
    return true;
  }

  /// CopyWith helper for dynamic updates
  SecurityConfig copyWith({
    bool? enableBiometrics,
    bool? enablePinFallback,
    int? maxAttempts,
    Duration? lockoutDuration,
    bool? vibrateOnTouch,
    bool? obscureInput,
    bool? enableServerValidation,
    String? serverEndpoint,
    Duration? serverTimeout,
    bool? allowOfflineFallback,
    double? serverConfidenceThreshold,
    bool? enableCertificatePinning,
  }) {
    return SecurityConfig(
      enableBiometrics: enableBiometrics ?? this.enableBiometrics,
      enablePinFallback: enablePinFallback ?? this.enablePinFallback,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      lockoutDuration: lockoutDuration ?? this.lockoutDuration,
      vibrateOnTouch: vibrateOnTouch ?? this.vibrateOnTouch,
      obscureInput: obscureInput ?? this.obscureInput,
      enableServerValidation: enableServerValidation ?? this.enableServerValidation,
      serverEndpoint: serverEndpoint ?? this.serverEndpoint,
      serverTimeout: serverTimeout ?? this.serverTimeout,
      allowOfflineFallback: allowOfflineFallback ?? this.allowOfflineFallback,
      serverConfidenceThreshold: serverConfidenceThreshold ?? this.serverConfidenceThreshold,
      enableCertificatePinning: enableCertificatePinning ?? this.enableCertificatePinning,
    );
  }
}
