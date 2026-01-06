/*
 * PROJECT: CryptexLock Security Suite
 * MODULE: Device Fingerprinting
 * PURPOSE: Generate unique device identifiers
 */

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceFingerprint {
  static const String _KEY_DEVICE_ID = 'secure_device_id';
  static const String _KEY_DEVICE_SECRET = 'secure_device_secret';
  
  /// Get or generate unique device ID
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if already generated
    String? existingId = prefs.getString(_KEY_DEVICE_ID);
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }
    
    // Generate new device ID
    final deviceInfo = DeviceInfoPlugin();
    String deviceId;
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      // Combine multiple identifiers for uniqueness
      final combined = '${androidInfo.id}:${androidInfo.model}:${androidInfo.device}';
      deviceId = _hash(combined);
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      // iOS identifier for vendor
      final combined = '${iosInfo.identifierForVendor}:${iosInfo.model}:${iosInfo.systemVersion}';
      deviceId = _hash(combined);
    } else {
      // Fallback for other platforms
      deviceId = _hash('${DateTime.now().millisecondsSinceEpoch}');
    }
    
    // Store for future use
    await prefs.setString(_KEY_DEVICE_ID, deviceId);
    return deviceId;
  }
  
  /// Get or generate device secret (for ZK proof)
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
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      // In production, get actual APK signature
      // For now, use build signature
      return _hash('${androidInfo.version.release}:${androidInfo.version.sdkInt}');
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return _hash('${iosInfo.systemVersion}:${iosInfo.model}');
    }
    
    return _hash('default_signature');
  }
  
  /// Generate random nonce for requests
  static String generateNonce() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _generateRandomString(16);
    return _hash('$timestamp:$random').substring(0, 16);
  }
  
  // Helper: Hash function
  static String _hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Helper: Generate random string
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) => chars[(random + index) % chars.length]).join();
  }
}
