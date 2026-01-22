// File: lib/main.dart
// 🛡️ Z-KINETIC V3.2 (FIREBASE BLACK BOX)
// Status: PRODUCTION READY & ERROR-SHIELDED ✅
// Auditor: Francois (Butler)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// 🔥 FIREBASE SUITE
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart'; 

// 🔐 Z-KINETIC INTERNAL MODULES
import 'cryptex_lock/cryptex_lock.dart' hide ClaController;
import 'cryptex_lock/src/cla_controller_v2.dart';
import 'cryptex_lock/src/device_integrity_attestation.dart';
import 'cryptex_lock/src/server_attestation_provider.dart';
import 'cryptex_lock/src/composite_attestation.dart';

void main() async {
  // Membungkus seluruh aplikasi dalam zon kawalan ralat
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 1. Inisialisasi Firebase dengan Kunci Besi yang disahkan
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // 2. Aktifkan App Check (Anti-Bot Protection)
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );

    // 3. Konfigurasi Crashlytics (Sistem Kotak Hitam)
    // Menangkap ralat Flutter secara automatik
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // 4. Autentikasi Sesi Anonim
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (kDebugMode) print('🔥 Z-Kinetic Session Authenticated');
    } catch (e) {
      if (kDebugMode) print('⚠️ Auth Error: $e');
    }

    // 5. Penetapan Orientasi Tegak
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 6. Inisialisasi Storan Tempatan
    try {
      await IncidentStorage.database;
      if (kDebugMode) print("🛡️ Local Audit Vault initialized.");
    } catch (e) {
      if (kDebugMode) print("⚠️ Vault Error: $e");
    }

    runApp(const MyApp());
  }, (error, stack) {
    // Menangkap ralat luar jangka dan hantar ke HQ (Firebase)
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
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
        useMaterial3: true,
      ),
      home: const BootLoader(),
    );
  }
}

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
    TransactionData data;
    try {
      // Mengambil data transaksi dengan Remote Salt yang kita set tadi
      data = await TransactionService.fetchCurrentTransaction();
    } catch (e) {
      // Protokol ralat jika sambungan gagal
      data = TransactionData(
        amount: "RM 0.00",
        securityHash: "ERR_HASH_RECON",
        transactionId: "OFFLINE_MODE"
      );
      FirebaseCrashlytics.instance.log("Transaction fetch failed: $e");
    }

    const config = SecurityConfig(
      enableCertificatePinning: true,
      enableIncidentReporting: true,
      autoReportCriticalThreats: true,
    );

    final mirrorService = MirrorService();
    final incidentReporter = IncidentReporter(
      mirrorService: mirrorService,
      config: config,
    );

    if (!mounted) return;
    
    // Transisi lancar ke skrin kunci utama
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LockScreen(
          systemName: "FIREBASE BLACK BOX",
          displayedAmount: data.amount,
          secureHash: data.securityHash,
          transactionId: data.transactionId,
          incidentReporter: incidentReporter,
          securityConfig: config,
        ),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 800),
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
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: Colors.cyanAccent,
                strokeWidth: 2,
              ),
            ),
            SizedBox(height: 30),
            Text(
              "INITIALIZING BLACK BOX...",
              style: TextStyle(
                color: Colors.cyanAccent,
                letterSpacing: 2,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// LOCK SCREEN
// ============================================

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

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    final deviceProvider = DeviceIntegrityAttestation(
      allowDebugMode: kDebugMode,
      allowEmulators: false,
    );

    final serverProvider = ServerAttestationProvider(
      ServerAttestationConfig(
        endpoint: const String.fromEnvironment(
          'ZK_API_ENDPOINT',
          defaultValue: 'https://api.z-kinetic.com/v1/unlock'
        ),
        apiKey: const String.fromEnvironment(
          'ZK_API_KEY',
          defaultValue: ''
        ),
      ),
    );

    final compositeProvider = CompositeAttestationProvider(
      [deviceProvider, serverProvider],
      strategy: AttestationStrategy.ALL_MUST_PASS,
    );

    _controller = ClaController(
      ClaConfig(
        secret: const [1, 7, 3, 9, 2],
        minShake: 0.4,
        thresholdAmount: 0.25,
        minSolveTime: const Duration(milliseconds: 600),
        maxAttempts: 5,
        jamCooldown: const Duration(seconds: 10),
        enableSensors: true,
        clientId: 'Z_KINETIC_PRO',
        clientSecret: const String.fromEnvironment(
          'ZK_CLIENT_SECRET',
          defaultValue: 'DEV_MODE_UNSECURED'
        ),
        attestationProvider: compositeProvider,
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

  void _onSuccess() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🔓 ACCESS GRANTED"), 
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("❌ INVALID CODE"), 
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  void _onJammed() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("⛔ SYSTEM HALTED"), 
        backgroundColor: Colors.deepOrange,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(backgroundColor: Colors.black);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.systemName, 
          style: const TextStyle(
            color: Colors.cyanAccent, 
            fontSize: 10,
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
              CryptexLock(
                controller: _controller,
                onSuccess: _onSuccess,
                onFail: _onFail,
                onJammed: _onJammed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
