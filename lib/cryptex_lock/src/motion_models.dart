// FILE: lib/cryptex_lock/src/motion_models.dart
// STATUS: COMPATIBLE WITH CONTROLLER V3 ✅

import 'dart:ui'; // Penting: Untuk guna 'Offset'

/// 1. Data Sentuhan (Touch)
/// Controller V3 panggil ini 'TouchData', bukan 'TouchEvent'
class TouchData {
  final DateTime timestamp;
  final double pressure;
  final Offset position;

  TouchData({
    required this.timestamp,
    required this.pressure,
    required this.position,
  });
}

/// 2. Data Gerakan (Motion)
/// Controller V3 panggil ini 'MotionData', bukan 'MotionEvent'
class MotionData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  MotionData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });
}

/// 3. Keputusan Validasi
/// Controller V3 cari 'isValid' & 'isPanic', bukan 'allowed'
class ValidationResult {
  final bool isValid;
  final bool isPanic;
  final String? message;

  ValidationResult({
    required this.isValid,
    this.isPanic = false, // Default false
    this.message,
  });
}

// --- KELAS TAMBAHAN (BACKUP) ---
// Jika ada fail lama yang masih guna nama ini, kita biarkan di bawah
// supaya tak error. Tapi Controller V3 akan guna yang di atas.

class BiometricSession {
  final String sessionId;
  // ... (Simplification for compatibility if needed)
  BiometricSession({required this.sessionId});
}
