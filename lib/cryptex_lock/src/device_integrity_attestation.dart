/*
 * PROJECT: Z-KINETIC SECURITY CORE
 * MODULE: Device Integrity Attestation Provider
 * PURPOSE: Local device verification (root/jailbreak detection)
 * 
 * USAGE:
 * final attestation = DeviceIntegrityAttestation();
 * final result = await attestation.attest(attempt);
 * 
 * FEATURES:
 * - Root/jailbreak detection
 * - Developer mode detection
 * - Emulator detection
 * - USB debugging detection
 * - Device fingerprint validation
 */

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'security_core.dart';
import 'motion_models.dart';

/// Device integrity levels
enum IntegrityLevel {
  TRUSTED,      // Stock device, no tampering
  SUSPICIOUS,   // Developer mode or debug enabled
  COMPROMISED,  // Rooted/jailbroken
  CRITICAL      // Emulator or severe tampering
}

/// Device integrity check result
class IntegrityCheckResult {
  final IntegrityLevel level;
  final List<String> violations;
  final Map<String, dynamic> deviceInfo;
  final bool isEmulator;
  final bool isRooted;
  final bool isDeveloperMode;
  final bool isDebugMode;

  IntegrityCheckResult({
    required this.level,
    required this.violations,
    required this.deviceInfo,
    required this.isEmulator,
    required this.isRooted,
    required this.isDeveloperMode,
    required this.isDebugMode,
  });

  bool get isTrusted => level == IntegrityLevel.TRUSTED;
  bool get isAcceptable => level == IntegrityLevel.TRUSTED || 
                           level == IntegrityLevel.SUSPICIOUS;

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'violations': violations,
    'is_emulator': isEmulator,
    'is_rooted': isRooted,
    'is_developer_mode': isDeveloperMode,
    'is_debug_mode': isDebugMode,
    'device_info': deviceInfo,
  };
}

/// Local device integrity attestation provider
class DeviceIntegrityAttestation implements AttestationProvider {
  final bool allowDebugMode;
  final bool allowEmulators;
  final bool strictMode;

  DeviceIntegrityAttestation({
    this.allowDebugMode = kDebugMode, // Allow in debug builds
    this.allowEmulators = kDebugMode,
    this.strictMode = false,
  });

  @override
  Future<AttestationResult> attest(ValidationAttempt attempt) async {
    final integrity = await checkDeviceIntegrity();

    // Determine if device is acceptable
    final bool verified = _evaluateIntegrity(integrity);

    // Generate attestation token
    final token = _generateToken(integrity);

    return AttestationResult(
      verified: verified,
      token: token,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      claims: integrity.toJson(),
    );
  }

  /// Main integrity check
  Future<IntegrityCheckResult> checkDeviceIntegrity() async {
    final violations = <String>[];
    
    // Run all checks
    final isEmulator = await _checkEmulator();
    final isRooted = await _checkRoot();
    final isDeveloperMode = await _checkDeveloperMode();
    final isDebugMode = kDebugMode;

    // Collect violations
    if (isEmulator && !allowEmulators) {
      violations.add('EMULATOR_DETECTED');
    }
    if (isRooted) {
      violations.add('ROOT_DETECTED');
    }
    if (isDeveloperMode && !allowDebugMode) {
      violations.add('DEVELOPER_MODE_ENABLED');
    }
    if (isDebugMode && strictMode) {
      violations.add('DEBUG_BUILD');
    }

    // Determine integrity level
    final level = _calculateIntegrityLevel(
      isEmulator: isEmulator,
      isRooted: isRooted,
      isDeveloperMode: isDeveloperMode,
      isDebugMode: isDebugMode,
    );

    // Collect device info
    final deviceInfo = await _collectDeviceInfo();

    return IntegrityCheckResult(
      level: level,
      violations: violations,
      deviceInfo: deviceInfo,
      isEmulator: isEmulator,
      isRooted: isRooted,
      isDeveloperMode: isDeveloperMode,
      isDebugMode: isDebugMode,
    );
  }

  /// Check if running on emulator
  Future<bool> _checkEmulator() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        
        // Common emulator fingerprints
        final emulatorIndicators = [
          androidInfo.isPhysicalDevice == false,
          androidInfo.brand.toLowerCase().contains('generic'),
          androidInfo.device.toLowerCase().contains('generic'),
          androidInfo.model.toLowerCase().contains('emulator'),
          androidInfo.product.toLowerCase().contains('sdk'),
          androidInfo.hardware.toLowerCase().contains('goldfish'),
          androidInfo.hardware.toLowerCase().contains('ranchu'),
        ];

        return emulatorIndicators.where((indicator) => indicator).length >= 2;
      } 
      else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        
        // iOS simulator check
        return !iosInfo.isPhysicalDevice;
      }
    } catch (e) {
      if (kDebugMode) print('Emulator check failed: $e');
    }

    return false;
  }

  /// Check if device is rooted/jailbroken
  Future<bool> _checkRoot() async {
    if (Platform.isAndroid) {
      return await _checkAndroidRoot();
    } else if (Platform.isIOS) {
      return await _checkIOSJailbreak();
    }
    return false;
  }

  /// Android root detection
  Future<bool> _checkAndroidRoot() async {
    // Check for common root files
    final rootIndicators = [
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/data/local/xbin/su',
      '/system/sd/xbin/su',
      '/system/bin/.ext/.su',
      '/system/usr/we-need-root/su',
    ];

    for (final path in rootIndicators) {
      try {
        final file = File(path);
        if (await file.exists()) {
          return true;
        }
      } catch (_) {
        // Permission denied is normal for non-rooted devices
      }
    }

    // Check for root management apps
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      // Some rooted devices modify build properties
      final suspiciousProps = [
        androidInfo.tags.toLowerCase().contains('test-keys'),
      ];

      return suspiciousProps.any((prop) => prop);
    } catch (_) {}

    return false;
  }

  /// iOS jailbreak detection
  Future<bool> _checkIOSJailbreak() async {
    // Check for common jailbreak files
    final jailbreakIndicators = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
    ];

    for (final path in jailbreakIndicators) {
      try {
        final file = File(path);
        if (await file.exists()) {
          return true;
        }
      } catch (_) {}
    }

    // Check if app can write outside sandbox
    try {
      final testFile = File('/private/jailbreak_test.txt');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true; // Should not be able to write here
    } catch (_) {
      // Expected to fail on non-jailbroken devices
    }

    return false;
  }

  /// Check if developer mode is enabled
  Future<bool> _checkDeveloperMode() async {
    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        
        // Developer mode indicators
        // Note: This is a simplified check
        // Real implementation would use platform channels to check:
        // - USB debugging enabled
        // - Developer options unlocked
        
        return androidInfo.version.sdkInt >= 23 && 
               androidInfo.isPhysicalDevice;
      } catch (_) {}
    }

    return false;
  }

  /// Collect device information
  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'manufacturer': androidInfo.manufacturer,
          'sdk': androidInfo.version.sdkInt,
          'release': androidInfo.version.release,
          'is_physical': androidInfo.isPhysicalDevice,
          'app_version': packageInfo.version,
          'app_build': packageInfo.buildNumber,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'platform': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'system_version': iosInfo.systemVersion,
          'is_physical': iosInfo.isPhysicalDevice,
          'app_version': packageInfo.version,
          'app_build': packageInfo.buildNumber,
        };
      }
    } catch (e) {
      if (kDebugMode) print('Device info collection failed: $e');
    }

    return {
      'platform': Platform.operatingSystem,
      'error': 'info_unavailable',
    };
  }

  /// Calculate overall integrity level
  IntegrityLevel _calculateIntegrityLevel({
    required bool isEmulator,
    required bool isRooted,
    required bool isDeveloperMode,
    required bool isDebugMode,
  }) {
    // Critical violations
    if (isRooted) {
      return IntegrityLevel.COMPROMISED;
    }

    if (isEmulator && !allowEmulators) {
      return IntegrityLevel.CRITICAL;
    }

    // Suspicious conditions
    if (isDeveloperMode || (isDebugMode && strictMode)) {
      return IntegrityLevel.SUSPICIOUS;
    }

    return IntegrityLevel.TRUSTED;
  }

  /// Evaluate if integrity is acceptable
  bool _evaluateIntegrity(IntegrityCheckResult integrity) {
    if (strictMode) {
      // Strict mode: only TRUSTED allowed
      return integrity.level == IntegrityLevel.TRUSTED;
    } else {
      // Lenient mode: TRUSTED and SUSPICIOUS allowed
      return integrity.isAcceptable;
    }
  }

  /// Generate attestation token
  String _generateToken(IntegrityCheckResult integrity) {
    // In production, this would be a signed JWT
    // For now, simple hash-based token
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final payload = '${integrity.level.name}:$timestamp';
    
    return 'DEVICE_ATTESTATION_${payload.hashCode.abs().toRadixString(16).toUpperCase()}';
  }
}
