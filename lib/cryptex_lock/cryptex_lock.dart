/*
 * PROJECT: CryptexLock Security Suite
 * FILE: lib/cryptex_lock/cryptex_lock.dart
 * PURPOSE: Barrel export file for clean imports
 * 
 * USAGE IN OTHER FILES:
 * import 'package:your_app/cryptex_lock/cryptex_lock.dart';
 * 
 * Instead of:
 * import 'package:your_app/cryptex_lock/src/cla_widget.dart';
 * import 'package:your_app/cryptex_lock/src/cla_controller.dart';
 * etc...
 */

// ============================================
// CORE COMPONENTS
// ============================================
export 'src/cla_widget.dart';
export 'src/cla_controller_v2.dart';
export 'src/cla_models.dart';
export 'src/security_engine.dart';

// ============================================
// SECURITY SUBSYSTEM
// ============================================
export 'src/security/config/security_config.dart';
export 'src/security/models/secure_payload.dart';

// NOTE: mirror_service must be exported AFTER secure_payload
// to avoid ServerVerdict conflict (mirror_service has the complete definition)
export 'src/security/services/device_fingerprint.dart';
export 'src/security/services/incident_reporter.dart';
export 'src/security/services/incident_storage.dart';
export 'src/security/services/mirror_service.dart'; // Moved to end

// ============================================
// BUSINESS SERVICES
// ============================================
export 'src/services/transaction_service.dart';
