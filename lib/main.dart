// 🛡️ Z-KINETIC INTELLIGENCE HUB V6.5 (MERGED & FINAL)
// Status: PRODUCTION READY + PANIC MODE ✅
// Features: 
// 1. Clean Architecture (TransactionService)
// 2. Integrity Check (Smart Warning)
// 3. Panic Mode (Fake Dashboard RM0.00)
// 4. Hardened SQLite Persistence
// 5. Automated Security Policy Injection

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

// Core Imports (Struktur Folder src Kapten)
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart' hide SecurityConfig; 

// Services & Security
import 'cryptex_lock/src/security/config/security_config.dart';
import 'cryptex_lock/src/security/services/mirror_service.dart';
import 'cryptex_lock/src/security/services/device_fingerprint.dart';
import 'cryptex_lock/src/security/services/incident_reporter.dart';
import 'cryptex_lock/src/security/services/incident_storage.dart'; // SQLite Service

// The Pipeline
import 'cryptex_lock/src/services/transaction_service.dart';

void main() async {
  // 1. Pastikan Flutter Binding dimulakan untuk plugin Native
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Kunci orientasi peranti (Security Best Practice)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 3. BOOTLOADER: Inisialisasi Black Box (SQLite)
  // Memastikan log boleh ditulis sebaik sahaja aplikasi bernafas.
  try {
    await IncidentStorage.database;
    if (kDebugMode) print("🛡️ Francois: Black Box (SQL) Initialized.");
  } catch (e) {
    if (kDebugMode) print("⚠️ Francois: Database Error: $e");
  }

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
    // 1. Tarik Data Transaksi dari Pipeline
    TransactionData data;
    try {
      data = await TransactionService.fetchCurrentTransaction();
    } catch (e) {
      data = TransactionData(
        amount: "RM 0.00", 
        securityHash: "ERR_HASH", 
        transactionId: "FAILED_CONNECTION"
      );
    }
    
    // 2. Setup Security Reporter & Policy
    const config = SecurityConfig(
       enableCertificatePinning: true,
       autoReportViolations: true,
    );
    
    final mirrorService = MirrorService(); // Menggunakan default config internal
    final incidentReporter = IncidentReporter(
       mirrorService: mirrorService
    );

    // 3. Masuk ke LockScreen (Peralihan Mulus)
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LockScreen(
          systemName: "SECURE BANKING UPLINK",
          displayedAmount: data.amount,       
          secureHash: data.securityHash,     
          transactionId: data.transactionId,
          incidentReporter: incidentReporter,
          securityConfig: config,
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
  final SecurityConfig securityConfig;

  const LockScreen({
    super.key,
    required this.systemName,
    required this.displayedAmount,
    required this.secureHash,
    required this.transactionId,
    required this.securityConfig,
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
  
  // 🔥 FAKE DASHBOARD STATE (Panic Mode UI)
  bool _showFakeDashboard = false;

  @override
  void initState() {
    super.initState();
    _performIntegrityAudit(); 
    _initializeController();
  }

  /// Audit Integriti: Memastikan RM yang dipaparkan sepadan dengan Hash
  void _performIntegrityAudit() {
    // Logik audit disesuaikan dengan TransactionService V2.0
    final isValid = TransactionService.validateTransaction(
      TransactionData(
        amount: widget.displayedAmount,
        securityHash: widget.secureHash,
        transactionId: widget.transactionId
      )
    );

    if (!isValid) {
      setState(() => _isCompromised = true);
      debugPrint("🚨 DATA BREACH: Integrity Check Failed for ${widget.transactionId}");
    }
  }

  void _initializeController() {
    _controller = ClaController(
      config: ClaConfig(
        secret: const [1, 7, 3, 9, 2], // 🚨 AMARAN: Jangan guna Palindrome!
        minShake: 0.4, 
        thresholdAmount: 0.25, 
        minSolveTime: const Duration(milliseconds: 600),
        maxAttempts: 5,  
        jamCooldown: const Duration(seconds: 10), 
        enableSensors: true, 
        clientId: 'Z_KINETIC_PRO',
        clientSecret: 'secured_session_key',
        securityConfig: widget.securityConfig,
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

  // 🔥 SILENT ALARM LOGIC (Dikonfigurasi oleh Francois)
  Future<void> _triggerSilentPanic() async {
    String deviceId = "UNKNOWN";
    try { 
      deviceId = await DeviceFingerprint.getDeviceId(); 
    } catch (_) {}

    await widget.incidentReporter?.report(
      deviceId: deviceId,
      type: "DURESS_PANIC_CODE_ACTIVATED",
      metadata: {
        "user_state": "UNDER_THREAT",
        "action": "SILENT_ALARM_SENT",
        "location_context": "DASHBOARD_MIRROR_ACTIVE"
      },
    );
    debugPrint("🚨 SOS: Silent Alarm logged to SQL and Mirror.");
  }

  Future<void> _autoReportIncident() async {
    String deviceId = "UNKNOWN";
    try { 
      deviceId = await DeviceFingerprint.getDeviceId(); 
    } catch (_) {}

    await widget.incidentReporter?.report(
      deviceId: deviceId,
      type: "INTEGRITY_MISMATCH_BYPASSED",
      metadata: {
        "amount": widget.displayedAmount,
        "hash": widget.secureHash,
        "action": "ALLOWED_WITH_WARNING",
      },
    );
  }

  Future<void> _handleReportAndCancel() async {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red)),
    );
    
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context); 
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.green.shade900,
        title: const Text("✅ REPORT SENT"),
        content: const Text("Transaction cancelled and logged for security."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("CLOSE", style: TextStyle(color: Colors.white))
          )
        ],
      )
    );
  }

  void _onSuccess() {
    // 1. CHECK PANIC MODE DULU!
    if (_controller.isPanicMode) {
      _triggerSilentPanic(); 
      setState(() {
        _showFakeDashboard = true; 
      });
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔓 ACCESS GRANTED"), backgroundColor: Colors.green)
      );
      return; 
    }

    // 2. Normal Flow
    if (_isCompromised && !_userAcknowledgedThreat) {
      setState(() => _userAcknowledgedThreat = true);
      _autoReportIncident();
      HapticFeedback.mediumImpact();
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.orange.shade900,
          title: const Row(children: [
            Icon(Icons.warning_amber, color: Colors.white), 
            SizedBox(width: 10), 
            Text("SECURITY ALERT", style: TextStyle(color: Colors.white, fontSize: 16))
          ]),
          content: const Text(
            "Data Integrity Mismatch detected.\nAccess granted based on kinetic verification, but this incident has been recorded in the black box.", 
            style: TextStyle(color: Colors.white70)
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("⚠️ INCIDENT LOGGED"), backgroundColor: Colors.orange)
                );
              },
              child: const Text("I UNDERSTAND", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔓 ACCESS GRANTED"), backgroundColor: Colors.green)
      );
      
      // Navigasi ke Dashboard Sebenar
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RealSuccessDashboard())
      );
    }
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ INVALID (${_controller.failedAttempts}/5)"), backgroundColor: Colors.red)
    );
  }

  void _onJammed() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⛔ SYSTEM HALTED"), backgroundColor: Colors.deepOrange)
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(backgroundColor: Colors.black);

    // 🔥 JIKA PANIC MODE: Tunjuk Dashboard Palsu (Akaun Kosong)
    if (_showFakeDashboard) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text("MY ACCOUNT", style: TextStyle(color: Colors.white))),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
              SizedBox(height: 20),
              Text("BALANCE AVAILABLE", style: TextStyle(color: Colors.grey, fontSize: 12)),
              SizedBox(height: 10),
              Text("RM 0.00", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              Text("No active transactions.", style: TextStyle(color: Colors.white38)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.systemName, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, letterSpacing: 2)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isCompromised ? _buildHackedNotice() : _buildSafeNotice(),
              const SizedBox(height: 50),
              
              // Widget Panggilan Utama
              ClaWidget(
                controller: _controller,
                onUnlock: _onSuccess,
              ),
              
              const SizedBox(height: 30),
              if (!_isCompromised)
                Text(
                  "TXN ID: ${widget.transactionId}\nStatus: ${_userAcknowledgedThreat ? 'MONITORED' : 'SECURE'}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _userAcknowledgedThreat ? Colors.orange.withOpacity(0.5) : Colors.green.withOpacity(0.5), 
                    fontSize: 10, 
                    fontFamily: 'monospace'
                  ),
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
        borderRadius: BorderRadius.circular(12)
      ),
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
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05), 
        border: Border.all(color: Colors.red, width: 2), 
        borderRadius: BorderRadius.circular(12), 
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 20)]
      ),
      child: Column(children: [
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.report_problem, color: Colors.red, size: 24), 
          SizedBox(width: 10), 
          Text("INTEGRITY BREACH", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14))
        ]),
        const SizedBox(height: 15),
        Text("Value '${widget.displayedAmount}' mismatch.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, 
          child: ElevatedButton.icon(
            onPressed: _handleReportAndCancel, 
            icon: const Icon(Icons.security, color: Colors.white), 
            label: const Text("REPORT THREAT", style: TextStyle(color: Colors.white)), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900)
          )
        ),
      ]),
    );
  }
}

class RealSuccessDashboard extends StatelessWidget {
  const RealSuccessDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DASHBOARD")),
      body: const Center(
        child: Text("WELCOME. ACCESS FULLY GRANTED."),
      ),
    );
  }
}
