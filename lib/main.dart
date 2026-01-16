// 🛡️ Z-KINETIC INTELLIGENCE HUB V3.1 (PRODUCTION FIX)
// Status: SMART WARNING SYSTEM ✅
// Fix: Detect attack → Warn user → Allow if Cryptex solved → Log incident

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

// Cryptex Lock Core
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart' hide SecurityConfig; 

// Security Services V3.0
import 'cryptex_lock/src/security/services/mirror_service.dart';
import 'cryptex_lock/src/security/services/device_fingerprint.dart';
import 'cryptex_lock/src/security/services/incident_reporter.dart';
import 'cryptex_lock/src/security/config/security_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Z-KINETIC PRO V3.1',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000), 
        primaryColor: Colors.cyanAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: Builder(
        builder: (context) {
          // Production Config
          final config = SecurityConfig.production(
            serverEndpoint: 'https://api.yourdomain.com',
            enableIncidentReporting: true,
            autoReportCriticalThreats: true,
            retryFailedReports: true,
          );

          final mirrorService = MirrorService(endpoint: config.serverEndpoint);
          final incidentReporter = IncidentReporter(
            mirrorService: mirrorService, 
            config: config
          );

          return LockScreen(
            systemName: "SECURE BANKING UPLINK",
            displayedAmount: "RM 50,000.00", 
            secureHash: "HASH-RM50.00",
            incidentReporter: incidentReporter,
          );
        }
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  final String systemName;
  final String displayedAmount;
  final String secureHash;
  final IncidentReporter? incidentReporter;

  const LockScreen({
    super.key,
    required this.systemName,
    required this.displayedAmount,
    required this.secureHash,
    this.incidentReporter,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;
  bool _isInitialized = false;
  bool _isCompromised = false;
  bool _userAcknowledgedThreat = false; // 🔥 NEW: Track if user aware

  @override
  void initState() {
    super.initState();
    _performIntegrityAudit(); 
    _initializeController();
  }

  void _performIntegrityAudit() {
    final calculatedHash = "HASH-${widget.displayedAmount.replaceAll(' ', '').replaceAll(',', '')}";
    if (calculatedHash != widget.secureHash) {
      setState(() {
        _isCompromised = true;
      });
      
      debugPrint("🚨 INTEGRITY BREACH DETECTED!");
      debugPrint("   Expected: ${widget.secureHash}");
      debugPrint("   Calculated: $calculatedHash");
    }
  }

  void _initializeController() {
    _controller = ClaController(
      const ClaConfig(
        secret: [1, 7, 3, 9, 2], 
        minShake: 0.4, 
        botDetectionSensitivity: 0.25,  
        thresholdAmount: 0.25, 
        minSolveTime: Duration(milliseconds: 600),
        maxAttempts: 5,  
        jamCooldown: Duration(seconds: 10), 
        enableSensors: true, 
        clientId: 'Z_KINETIC_V3.1_PRODUCTION',
        clientSecret: 'production_intelligence_key',
      ),
    );
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.incidentReporter?.dispose();
    super.dispose();
  }

  // 🔥 AUTO-REPORT INCIDENT (Background)
  Future<void> _autoReportIncident() async {
    String deviceId = "UNKNOWN_DEVICE";
    try {
      deviceId = await DeviceFingerprint.getDeviceId();
    } catch (e) {
      debugPrint("Device ID Error: $e");
    }

    final report = SecurityIncidentReport(
      incidentId: "INC-${DateTime.now().millisecondsSinceEpoch}",
      timestamp: DateTime.now().toIso8601String(),
      deviceId: deviceId,
      attackType: "DATA_INTEGRITY_MISMATCH_BYPASSED",
      detectedValue: widget.displayedAmount,
      expectedSignature: widget.secureHash,
      action: "ALLOWED_WITH_WARNING",
    );

    if (widget.incidentReporter != null) {
      // Silent background report
      widget.incidentReporter!.report(report).then((result) {
        debugPrint("📡 Background Report: ${result.status}");
      });
    }
  }

  Future<void> _handleReportAndCancel() async {
    HapticFeedback.heavyImpact();
    
    String deviceId = "UNKNOWN_DEVICE";
    try {
      deviceId = await DeviceFingerprint.getDeviceId();
    } catch (e) {
      debugPrint("Device ID Error: $e");
    }

    final report = SecurityIncidentReport(
      incidentId: "INC-${DateTime.now().millisecondsSinceEpoch}",
      timestamp: DateTime.now().toIso8601String(),
      deviceId: deviceId,
      attackType: "OVERLAY_MANIPULATION_USER_REPORTED",
      detectedValue: widget.displayedAmount,
      expectedSignature: widget.secureHash,
      action: "BLOCKED_BY_USER",
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.white),
            SizedBox(width: 10),
            Text("SECURING DATA", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          "Encrypting forensic evidence...\nSending to Intelligence Hub...\nNotifying banking partner...",
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );

    if (widget.incidentReporter != null) {
      await widget.incidentReporter!.report(report);
    } else {
      await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green.shade900,
        title: const Text("✅ THREAT NEUTRALIZED"),
        content: Text(
          "Report ID: ${report.incidentId}\n\n"
          "Evidence has been locked.\n"
          "Transaction terminated."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("DONE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🔥 PRODUCTION FIX: Smart Warning System
  void _onSuccess() {
    if (_isCompromised && !_userAcknowledgedThreat) {
      // First time success after breach detection
      setState(() {
        _userAcknowledgedThreat = true;
      });
      
      // Auto-report in background (silent)
      _autoReportIncident();
      
      // Show warning but allow access
      HapticFeedback.mediumImpact();
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.orange.shade900,
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white, size: 32),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "SECURITY WARNING",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            "⚠️ INTEGRITY MISMATCH DETECTED\n\n"
            "Displayed amount does not match secure signature.\n\n"
            "Access granted based on biometric verification, but this incident has been logged for review.\n\n"
            "If you did not authorize this transaction, please report immediately.",
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("⚠️ ACCESS GRANTED - INCIDENT LOGGED"),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: const Text(
                "I UNDERSTAND",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      // Normal success (no breach or already acknowledged)
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🔓 ACCESS GRANTED"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("❌ INVALID (${_controller.failedAttempts}/5)"),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _onJammed() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("⛔ SECURITY LOCKOUT: ${_controller.remainingLockoutSeconds}s"),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Z-KINETIC SECURE GATEWAY",
          style: TextStyle(
            color: Colors.cyanAccent,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isCompromised ? _buildHackedNotice() : _buildSafeNotice(),
              
              const SizedBox(height: 50),

              CryptexLock(
                controller: _controller,
                onSuccess: _onSuccess,
                onFail: _onFail,
                onJammed: _onJammed,
              ),
              
              const SizedBox(height: 30),
              
              if (!_isCompromised)
                Column(
                  children: [
                    const Text(
                      "Target Code: 1-7-3-9-2",
                      style: TextStyle(color: Colors.white10, fontSize: 10),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "System Status: ${_userAcknowledgedThreat ? 'MONITORED' : 'SECURE'}",
                      style: TextStyle(
                        color: _userAcknowledgedThreat 
                            ? Colors.orange.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                        fontSize: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DATA INTEGRITY: VERIFIED",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.displayedAmount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHackedNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.report_problem, color: Colors.red, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "INTEGRITY BREACH DETECTED",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "ALERT: Displayed value '${widget.displayedAmount}' does not match secure signature.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 5),
          const Text(
            "Possible MITM or Overlay Attack detected.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleReportAndCancel,
              icon: const Icon(Icons.security, color: Colors.white),
              label: const Text(
                "CANCEL & REPORT TO HQ",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
