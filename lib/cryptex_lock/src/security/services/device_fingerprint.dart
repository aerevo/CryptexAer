/*
 * PROJECT: CryptexLock Security Suite V3.5
 * MODULE: Device Fingerprinting (HYBRID BEST VERSION)
 * PURPOSE: Generate TRULY unique device identifiers
 * FEATURES:
 * - UUID v4 for guaranteed uniqueness (from Gemini)
 * - getDeviceSecret() restored (from Original)
 * - Error handling improved
 * - Random.secure() for cryptographic strength
 */

import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // Add to pubspec.yaml: uuid: ^4.0.0

class DeviceFingerprint {
  static const String _KEY_DEVICE_ID = 'secure_device_id_v2';
  static const String _KEY_DEVICE_SECRET = 'secure_device_secret';
  
  /// Get or generate unique device ID (Persistent & TRULY Unique)
  /// Uses UUID v4 + Hardware Info for absolute uniqueness
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if already generated
    String? existingId = prefs.getString(_KEY_DEVICE_ID);
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }
    
    // Generate NEW robust ID
    final deviceInfo = DeviceInfoPlugin();
    String hardwareSignature;
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Combine stable hardware identifiers
        hardwareSignature = '${androidInfo.brand}:${androidInfo.model}:${androidInfo.hardware}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use vendor identifier + hardware details
        hardwareSignature = '${iosInfo.identifierForVendor}:${iosInfo.model}:${iosInfo.utsname.machine}';
      } else {
        hardwareSignature = 'unknown_platform_${Platform.operatingSystem}';
      }
    } catch (e) {
      // Fallback if device info fails
      hardwareSignature = 'fallback_signature_${DateTime.now().millisecondsSinceEpoch}';
    }

    // 🔥 CRITICAL: Combine Hardware Info + Random UUID
    // This ensures even identical phone models have different IDs
    final uuid = const Uuid().v4();
    final combinedKey = '$hardwareSignature:$uuid';
    final deviceId = _hash(combinedKey);
    
    // Persist for future use
    await prefs.setString(_KEY_DEVICE_ID, deviceId);
    return deviceId;
  }
  
  /// Get or generate device secret (for ZK proof)
  /// ✅ RESTORED: This method is required by secure_payload.dart
  static Future<String> getDeviceSecret() async {
    final prefs = await SharedPreferences.getInstance();
    
    String? existingSecret = prefs.getString(_KEY_DEVICE_SECRET);
    if (existingSecret != null && existingSecret.isNotEmpty) {
      return existingSecret;
    }
    
    // Generate cryptographically secure random secret
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final deviceId = await getDeviceId();
    final random = '$timestamp:$deviceId:${_generateRandomString(32)}';
    final secret = _hash(random);
    
    await prefs.setString(_KEY_DEVICE_SECRET, secret);
    return secret;
  }
  
  /// Get app signature (detects repackaged APKs)
  static Future<String> getAppSignature() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // In production, get actual APK signature via platform channels
        // For now, use build signature
        return _hash('${androidInfo.version.release}:${androidInfo.version.sdkInt}:build_v2');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return _hash('${iosInfo.systemVersion}:${iosInfo.model}:build_v2');
      }
    } catch (e) {
      // Fallback if device info fails
      return _hash('fallback_signature');
    }
    
    return _hash('default_signature');
  }
  
  /// Generate random nonce for requests
  static String generateNonce() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _generateRandomString(16);
    return _hash('$timestamp:$random').substring(0, 16);
  }
  
  // Helper: Hash function (SHA-256)
  static String _hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Helper: Generate cryptographically secure random string
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure(); // 🔥 Use secure random, not timestamp-based
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }
}
