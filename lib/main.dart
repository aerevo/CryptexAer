// File: lib/main.dart (FIXED ✅)
// 🛡️ Z-KINETIC V3.3 (FINAL INTEGRATION)
// Status: PRODUCTION READY

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
import 'cryptex_lock/src/cla_models.dart';

// 🏦 FAKE BANK SCREEN (Panic Mode Destination)
import 'screens/fake_bank_screen.dart';

void main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Inisialisasi Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. App Check (Security)
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.appAttest,
    );

    // 3. Crashlytics Setup
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // 4. Lock Orientation (Portrait only)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    runApp(const ZKineticApp());
  }, (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
}

class ZKineticApp extends StatelessWidget {
  const ZKineticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Z-Kinetic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: Colors.cyanAccent,
        useMaterial3: true,
      ),
      home: const LockScreen(systemName: "Z-KINETIC CORE"),
    );
  }
}

class LockScreen extends StatefulWidget {
  final String systemName;
  const LockScreen({super.key, required this.systemName});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

// ✅ FIXED: Complete _LockScreenState
class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    // 1. Setup Config
    final config = ClaConfig(
      secret: [1, 2, 3, 4, 5],
      maxAttempts: 3,
      jamCooldown: const Duration(seconds: 30),
      minSolveTime: const Duration(milliseconds: 500),
      minShake: 2.0,
      thresholdAmount: 5.0,
    );

    // 2. Setup Attestation
    final deviceAttest = DeviceIntegrityAttestation();
    
    final serverConfig = ServerAttestationConfig(
      endpoint: "https://api.z-kinetic.com/verify",
      apiKey: "zk_live_xxx",
    );
    final serverAttest = ServerAttestationProvider(serverConfig);

    // ✅ FIXED: CompositeAttestationProvider (bukan CompositeAttestation)
    final compositeAttest = CompositeAttestationProvider(
      [deviceAttest, serverAttest],
      strategy: AttestationStrategy.WEIGHTED,
      requiredConfidence: 0.85,
    );

    // 3. Setup Controller
    _controller = ClaController(
      config: config.copyWith(attestationProvider: compositeAttest),
    );

    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ✅ UPDATED SUCCESS HANDLER (Panic Mode Logic)
  void _onSuccess() {
    HapticFeedback.mediumImpact();

    // Check for Panic Mode trigger
    if (_controller.isPanicMode) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => const FakeBankScreen()
      ));
      return;
    }

    // Normal Success
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
    if (!_isInitialized) {
      return const Scaffold(backgroundColor: Colors.black);
    }

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
            fontWeight: FontWeight.w600,
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
              const SizedBox(height: 40),

              // Optional: Visualize Biometric Score
              ValueListenableBuilder<double>(
                valueListenable: _controller.touchScore,
                builder: (context, score, _) {
                  if (score == 0) return const SizedBox.shrink();
                  return Text(
                    "HUMANITY SCORE: ${(score * 100).toStringAsFixed(1)}%",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
