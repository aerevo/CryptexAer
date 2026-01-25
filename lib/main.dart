// File: lib/main.dart
// 🛡️ Z-KINETIC V3.3 (FINAL INTEGRATION)
// Status: PRODUCTION READY ✅
// Update: Wired Panic Mode & Fake Bank Screen

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

// 🏦 FAKE BANK SCREEN (Panic Mode Destination)
// Pastikan fail ini wujud di folder lib/screens/
import 'screens/fake_bank_screen.dart'; 

void main() async {
  // Membungkus seluruh aplikasi dalam zon kawalan ralat
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
        scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Deep Black
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

class _LockScreenState extends State<LockScreen> {
  late final ClaController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSystem();
  }

  Future<void> _initSystem() async {
    // Setup Attestation Layers
    final deviceAttest = DeviceIntegrityAttestation();
    final serverAttest = ServerAttestationProvider();
    final compositeAttest = CompositeAttestation(
      deviceAttestation: deviceAttest,
      serverAttestation: serverAttest,
    );

    // Configure Lock Logic
    final config = ClaConfig(
      secret: [1, 9, 5, 7], // Default PIN (Panic PIN will be 7-5-9-1)
      maxAttempts: 3,
      jamCooldown: const Duration(minutes: 1),
      attestationProvider: compositeAttest,
    );

    _controller = ClaController(config: config);
    
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
      // Navigate to Fake Bank Screen
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => const FakeBankScreen() 
      ));
      return; // Stop here, don't show success message
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
    
    // Note: The random wheel spin animation is triggered automatically 
    // by the widget listening to the controller
    
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
              
              // Optional: Visualize Biometric Score (for demo/debugging)
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
