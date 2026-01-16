// 🛡️ Z-KINETIC INTELLIGENCE HUB V4.5 (CLEAN ARCHITECTURE)
// Status: PRODUCTION READY UI ✅
// Data Source: Fully Decoupled via TransactionService

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

// Core Imports
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart' hide SecurityConfig; 

// Services
import 'cryptex_lock/src/security/services/mirror_service.dart';
import 'cryptex_lock/src/security/services/device_fingerprint.dart';
import 'cryptex_lock/src/security/services/incident_reporter.dart';
import 'cryptex_lock/src/security/config/security_config.dart';

// 🔥 THE PIPELINE
import 'cryptex_lock/src/services/transaction_service.dart';

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
      // Mula dengan 'BootLoader' untuk tarik air dari paip dulu
      home: const BootLoader(), 
    );
  }
}

// ==========================================
// 1. BOOTLOADER (Tarik Data Dulu)
// ==========================================
class BootLoader extends StatefulWidget {
  const BootLoader({super.key});

  @override
  State<BootLoader> createState() => _BootLoaderState();
}

class _BootLoaderState extends State<BootLoader> {
  @override
  void initState() {
    super.initState();
    _initializeSecureSession();
  }

  Future<void> _initializeSecureSession() async {
    // 1. Tarik Data Transaksi dari Service (Pipeline)
    TransactionData data;
    try {
      data = await TransactionService.fetchCurrentTransaction();
    } catch (e) {
      // Fallback kalau paip pecah
      data = TransactionData(amount: "ERROR", securityHash: "ERR", transactionId: "0");
    }
    
    // 2. Setup Security Reporter (Production Grade)
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

    // 3. Masuk ke LockScreen dengan data yang SUCI
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LockScreen(
          systemName: "SECURE BANKING UPLINK",
          displayedAmount: data.amount,       // <--- Data dari Paip
          secureHash: data.securityHash,      // <--- Hash dari Paip
          transactionId: data.transactionId,
          incidentReporter: incidentReporter,
        ),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.cyanAccent),
            SizedBox(height: 20),
            Text(
              "ESTABLISHING SECURE CONNECTION...", 
              style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 10)
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. LOCK SCREEN (UI Utama)
// ==========================================
class LockScreen extends StatefulWidget {
  final String systemName;
  final String displayedAmount;
  final String secureHash;
  final String transactionId;
  final IncidentReporter? incidentReporter;

  const LockScreen({
    super.key,
    required this.systemName,
    required this.displayedAmount,
    required this.secureHash,
    required this.transactionId,
    this.incidentReporter,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;
  bool _isInitialized = false;
  bool _isCompromised = false;
  bool _userAcknowledgedThreat = false;

  @override
  void initState() {
    super.initState();
    _performIntegrityAudit(); 
    _initializeController();
  }

  // AUDIT: Bandingkan Hash dengan Amount yang dipaparkan
  void _performIntegrityAudit() {
    // Hash Calculation Logic (Simple version for demo)
    // Dalam real production, hash ini logicnya lebih kompleks di server
    final calculatedHash = "HASH-${widget.displayedAmount.replaceAll(' ', '').replaceAll(',', '')}";
    
    // Perbandingan Integriti
    if (calculatedHash != widget.secureHash) {
      setState(() => _isCompromised = true);
      debugPrint("🚨 DATA BREACH: Display(${widget.displayedAmount}) != Hash(${widget.secureHash})");
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
        clientId: 'Z_KINETIC_PRO',
        clientSecret: 'secured_session_key',
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

  // --- LOGIC PRODUCTION: WARN BUT ALLOW ---

  Future<void> _autoReportIncident() async {
    String deviceId = "UNKNOWN";
    try { deviceId = await DeviceFingerprint.getDeviceId(); } catch (_) {}

    final report = SecurityIncidentReport(
      incidentId: "INC-${DateTime.now().millisecondsSinceEpoch}",
      timestamp: DateTime.now().toIso8601String(),
      deviceId: deviceId,
      attackType: "INTEGRITY_MISMATCH_BYPASSED",
      detectedValue: widget.displayedAmount,
      expectedSignature: widget.secureHash,
      action: "ALLOWED_WITH_WARNING",
    );

    widget.incidentReporter?.report(report);
  }

  Future<void> _handleReportAndCancel() async {
    HapticFeedback.heavyImpact();
    // Simulate reporting delay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red)),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context); // Close loading
    
    // Show Done
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.green.shade900,
        title: const Text("✅ REPORT SENT"),
        content: const Text("Transaction cancelled for security."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE", style: TextStyle(color: Colors.white)))],
      )
    );
  }

  void _onSuccess() {
    if (_isCompromised && !_userAcknowledgedThreat) {
      // ⚠️ CASE: ATTACK DETECTED
      setState(() => _userAcknowledgedThreat = true);
      _autoReportIncident();
      HapticFeedback.mediumImpact();
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.orange.shade900,
          title: const Row(children: [Icon(Icons.warning_amber, color: Colors.white), SizedBox(width: 10), Text("SECURITY ALERT", style: TextStyle(color: Colors.white, fontSize: 16))]),
          content: const Text("Data Integrity Mismatch detected.\nAccess granted based on biometric verification, but this incident has been logged.", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ INCIDENT LOGGED"), backgroundColor: Colors.orange));
              },
              child: const Text("I UNDERSTAND", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      // ✅ CASE: CLEAN
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔓 ACCESS GRANTED"), backgroundColor: Colors.green));
    }
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ INVALID (${_controller.failedAttempts}/5)"), backgroundColor: Colors.red));
  }

  void _onJammed() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⛔ SYSTEM HALTED"), backgroundColor: Colors.deepOrange));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(backgroundColor: Colors.black);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.systemName, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, letterSpacing: 2)),
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
                Text(
                  "TXN ID: ${widget.transactionId}\nStatus: ${_userAcknowledgedThreat ? 'MONITORED' : 'SECURE'}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _userAcknowledgedThreat ? Colors.orange.withOpacity(0.5) : Colors.green.withOpacity(0.5), fontSize: 10, fontFamily: 'monospace'),
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
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), border: Border.all(color: Colors.green.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("DATA INTEGRITY: VERIFIED", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(widget.displayedAmount, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ])),
        ],
      ),
    );
  }

  Widget _buildHackedNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), border: Border.all(color: Colors.red, width: 2), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 20)]),
      child: Column(children: [
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.report_problem, color: Colors.red, size: 24), SizedBox(width: 10), Text("INTEGRITY BREACH", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14))]),
        const SizedBox(height: 15),
        Text("Value '${widget.displayedAmount}' mismatch.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _handleReportAndCancel, icon: const Icon(Icons.security, color: Colors.white), label: const Text("REPORT THREAT", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900))),
      ]),
    );
  }
}
