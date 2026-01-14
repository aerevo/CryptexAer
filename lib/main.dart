// 🛡️ Z-KINETIC INTELLIGENCE HUB V3.0 (PRODUCTION)
// Status: FULL INTEGRATION WITH INCIDENT REPORTING ✅
// Features: Auto-Detection + Server Reporting + Offline Backup

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

// Cryptex Lock Core
// ✅ FIX: Guna 'hide' untuk elak konflik SecurityConfig dari cla_models
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart' hide SecurityConfig; 

// 🔥 Security Services V3.0
import 'cryptex_lock/src/security/services/mirror_service.dart'; // Import model SecurityIncidentReport dari sini
import 'cryptex_lock/src/security/services/device_fingerprint.dart';
import 'cryptex_lock/src/security/services/incident_reporter.dart';
import 'cryptex_lock/src/security/config/security_config.dart'; // Ini sumber sebenar SecurityConfig yang baru

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
      title: 'Z-KINETIC PRO',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000), 
        primaryColor: Colors.cyanAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      // 🔥 INITIALIZATION: Setup Security Config & Services
      home: Builder(
        builder: (context) {
          // 1. Setup Config (Banking Grade)
          final config = SecurityConfig.production(
            serverEndpoint: 'https://api.yourdomain.com', // Ganti dengan IP laptop untuk test
            enableIncidentReporting: true,
            autoReportCriticalThreats: true,
            retryFailedReports: true,
          );

          // 2. Setup Services
          final mirrorService = MirrorService(endpoint: config.serverEndpoint);
          final incidentReporter = IncidentReporter(
            mirrorService: mirrorService, 
            config: config
          );

          return LockScreen(
            systemName: "SECURE BANKING UPLINK",
            displayedAmount: "RM 50,000.00", 
            secureHash: "HASH-RM50.00",
            incidentReporter: incidentReporter, // Pass reporter ke screen
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
  final IncidentReporter? incidentReporter; // Tambah parameter reporter

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
        clientId: 'Z_KINETIC_FINAL_PRO',
        clientSecret: 'audit_passed_intelligence_hub',
      ),
    );
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.incidentReporter?.dispose(); // Cleanup timer background
    super.dispose();
  }

  Future<void> _handleReportAndCancel() async {
    HapticFeedback.heavyImpact();
    
    // 1. Dapatkan Device ID sebenar
    String deviceId = "UNKNOWN_DEVICE";
    try {
      deviceId = await DeviceFingerprint.getDeviceId();
    } catch (e) {
      debugPrint("Device ID Error: $e");
    }

    // 2. Buat Laporan Forensik (Guna Model dari mirror_service)
    final report = SecurityIncidentReport(
      incidentId: "INC-${DateTime.now().millisecondsSinceEpoch}",
      timestamp: DateTime.now().toIso8601String(),
      deviceId: deviceId,
      attackType: "OVERLAY_MANIPULATION",
      detectedValue: widget.displayedAmount,
      expectedSignature: widget.secureHash,
      action: "BLOCK_AND_REPORT",
    );

    // 3. UI Loading
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
        content: const Text("Sending forensic report to Intelligence Hub...\nNotifying banking partner...", style: TextStyle(color: Colors.white70)),
      ),
    );

    // 4. Hantar Laporan Guna Incident Reporter
    if (widget.incidentReporter != null) {
      await widget.incidentReporter!.report(report);
    } else {
      // Fallback kalau reporter tak initialize (untuk testing sahaja)
      await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    // 5. Success Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green.shade900,
        title: const Text("✅ THREAT NEUTRALIZED"),
        content: Text("Report ID: ${report.incidentId}\n\nEvidence has been locked. Transaction terminated."),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("DONE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onSuccess() {
    if (_isCompromised) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ CRITICAL: SYSTEM LOCKED DUE TO DATA BREACH"), backgroundColor: Colors.red),
      );
    } else {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔓 ACCESS GRANTED"), backgroundColor: Colors.green),
      );
    }
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ INVALID (${_controller.failedAttempts}/5)"), backgroundColor: Colors.red),
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
    if (!_isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Z-KINETIC SECURE GATEWAY", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, letterSpacing: 2)),
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
                const Text("Target Code: 1-7-3-9-2", style: TextStyle(color: Colors.white10, fontSize: 10)),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("DATA INTEGRITY: VERIFIED", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(widget.displayedAmount, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ],
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
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.report_problem, color: Colors.red),
              SizedBox(width: 10),
              Text("INTEGRITY BREACH DETECTED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text("Displayed value '${widget.displayedAmount}' does not match secure signature.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleReportAndCancel,
              icon: const Icon(Icons.security, color: Colors.white),
              label: const Text("CANCEL & GENERATE REPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
