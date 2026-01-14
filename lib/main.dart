// 🛡️ Z-KINETIC INTELLIGENCE HUB V3.0 (PRODUCTION)
// Status: FULL INTEGRATION WITH INCIDENT REPORTING ✅
// Features: Auto-Detection + Server Reporting + Offline Backup

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

// Cryptex Lock Core
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart';

// 🔥 Security Services V3.0
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
      title: 'Z-KINETIC PRO V3.0',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: Colors.cyanAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const LockScreen(
        systemName: "SECURE BANKING UPLINK",
        displayedAmount: "RM 50,000.00",  // 😈 Hacker's value
        secureHash: "HASH-RM50.00",       // 🛡️ Real signature
      ),
    );
  }
}

// =========================================================
// 🔒 LOCK SCREEN (INTELLIGENCE HUB)
// =========================================================

class LockScreen extends StatefulWidget {
  final String systemName;
  final String displayedAmount;
  final String secureHash;

  const LockScreen({
    super.key,
    required this.systemName,
    required this.displayedAmount,
    required this.secureHash,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;
  late IncidentReporter _incidentReporter;
  
  bool _isInitialized = false;
  bool _isCompromised = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _performIntegrityAudit();
    _initializeController();
  }

  // 🔥 Initialize security services
  Future<void> _initializeServices() async {
    // Get device ID
    _deviceId = await DeviceFingerprint.getDeviceId();
    
    // Configure security (Production mode)
    final config = SecurityConfig.production(
      serverEndpoint: 'https://api.yourserver.com', // 🔧 Change to your server
    );
    
    // Initialize mirror service
    final mirrorService = MirrorService(
      endpoint: config.serverEndpoint,
    );
    
    // Initialize incident reporter
    _incidentReporter = IncidentReporter(
      mirrorService: mirrorService,
      config: config,
    );
  }

  // 🕵️‍♂️ Integrity audit (auto-detection)
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
        clientId: 'Z_KINETIC_V3_PRODUCTION',
        clientSecret: 'intel_hub_production_key',
      ),
    );
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _incidentReporter.dispose(); // Stop background retry service
    _controller.dispose();
    super.dispose();
  }

  // 🔥 Report incident to server
  Future<void> _handleReportAndCancel() async {
    HapticFeedback.heavyImpact();
    
    // Create incident report
    final report = SecurityIncidentReport(
      incidentId: "INC-${DateTime.now().millisecondsSinceEpoch}",
      timestamp: DateTime.now().toIso8601String(),
      deviceId: _deviceId ?? "UNKNOWN_DEVICE",
      attackType: "DATA_INTEGRITY_MISMATCH",
      originalAmount: widget.secureHash.replaceAll('HASH-', ''),
      manipulatedAmount: widget.displayedAmount,
      status: "REPORTED_TO_HQ",
    );

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 15),
            Text(
              "SECURING DATA",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        content: const Text(
          "Encrypting forensic evidence...\nSending to Intelligence Hub...\nNotifying banking partner...",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );

    // Report to server
    final result = await _incidentReporter.report(report);
    
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    // Prepare result message
    String statusMessage;
    Color statusColor;
    IconData statusIcon;
    
    if (result.status == 'REPORTED_TO_SERVER') {
      statusMessage = "✅ INCIDENT #${result.incidentId} LOGGED\n"
                     "✅ SERVER ACKNOWLEDGED\n"
                     "✅ TRANSACTION BLOCKED";
      statusColor = Colors.green.shade900;
      statusIcon = Icons.shield;
      
      // Show threat analysis if available
      if (result.receipt?.threatAnalysis != null) {
        final analysis = result.receipt!.threatAnalysis!;
        statusMessage += "\n\n🔍 THREAT ANALYSIS:\n"
                        "Type: ${analysis.type}\n"
                        "Vector: ${analysis.attackVector}\n"
                        "Confidence: ${(analysis.confidence * 100).toInt()}%";
      }
    } else if (result.status == 'QUEUED_FOR_RETRY') {
      statusMessage = "✅ INCIDENT #${result.incidentId} SAVED\n"
                     "⏳ QUEUED FOR RETRY\n"
                     "✅ TRANSACTION BLOCKED";
      statusColor = Colors.orange.shade900;
      statusIcon = Icons.cloud_off;
    } else {
      statusMessage = "✅ INCIDENT LOGGED LOCALLY\n"
                     "⚠️ SERVER UNAVAILABLE\n"
                     "✅ TRANSACTION BLOCKED";
      statusColor = Colors.orange.shade900;
      statusIcon = Icons.save;
    }

    // Show result dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: statusColor,
        title: Row(
          children: [
            Icon(statusIcon, color: Colors.white),
            const SizedBox(width: 10),
            const Text(
              "THREAT NEUTRALIZED",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          statusMessage,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to previous screen
            },
            child: const Text(
              "CLOSE",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _onSuccess() {
    if (_isCompromised) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ CRITICAL: SYSTEM LOCKED DUE TO DATA BREACH"),
          backgroundColor: Colors.red,
        ),
      );
    } else {
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
              // Status banner
              _isCompromised ? _buildHackedNotice() : _buildSafeNotice(),
              
              const SizedBox(height: 50),

              // Cryptex Lock
              CryptexLock(
                controller: _controller,
                onSuccess: _onSuccess,
                onFail: _onFail,
                onJammed: _onJammed,
              ),
              
              const SizedBox(height: 30),
              
              // Debug info (only in safe mode)
              if (!_isCompromised)
                Column(
                  children: [
                    const Text(
                      "Target Code: 1-7-3-9-2",
                      style: TextStyle(color: Colors.white10, fontSize: 10),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Device: ${_deviceId?.substring(0, 12) ?? 'Loading...'}",
                      style: const TextStyle(
                        color: Colors.white10,
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

  // 🟢 Safe UI
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

  // 🔴 Hacked UI
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
          
          // Report button
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
