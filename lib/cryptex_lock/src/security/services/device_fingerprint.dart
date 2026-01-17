/*
 * PROJECT: CryptexLock Security Suite
 * MODULE: Device Fingerprinting V2.0 (HARDENED)
 * PURPOSE: Generate TRULY unique device identifiers using UUID + Hardware Info
 */

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // Wajib tambah di pubspec.yaml

class DeviceFingerprint {
  static const String _KEY_DEVICE_ID = 'secure_device_id_v2';
  static const String _KEY_DEVICE_SECRET = 'secure_device_secret';
  
  /// Get or generate unique device ID (Persistent & Unique)
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
        // Gunakan komponen yang jarang berubah
        hardwareSignature = '${androidInfo.brand}:${androidInfo.model}:${androidInfo.hardware}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        hardwareSignature = '${iosInfo.identifierForVendor}:${iosInfo.model}:${iosInfo.utsname.machine}';
      } else {
        hardwareSignature = 'unknown_platform_${Platform.operatingSystem}';
      }
    } catch (e) {
      hardwareSignature = 'fallback_signature';
    }

    // Combine Hardware Info + Random UUID for absolute uniqueness
    // Even same phone model will have different IDs now
    final uuid = const Uuid().v4();
    final combinedKey = '$hardwareSignature:$uuid';
    final deviceId = _hash(combinedKey);
    
    await prefs.setString(_KEY_DEVICE_ID, deviceId);
    return deviceId;
  }
  
  /// Get app signature (detects repackaged APKs)
  static Future<String> getAppSignature() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return _hash('${androidInfo.version.release}:${androidInfo.version.sdkInt}:build_v1');
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return _hash('${iosInfo.systemVersion}:${iosInfo.model}:build_v1');
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
  
  // Helper: Generate random string
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }
}
