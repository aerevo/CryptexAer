import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart'; 

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
      title: 'Z-KINETIC DEV',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
      ),
      home: const LockScreen(),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;

  @override
  void initState() {
    super.initState();
    
    // 🔓 GOD MODE CONFIGURATION
    // Setting ini mematikan semua "Security Engine" supaya Kapten boleh test password.
    
    _controller = ClaController(
      const ClaConfig(
        secret: [1, 7, 3, 9, 2], 
        
        // 👇 SET SEMUA JADI KOSONG (0.0)
        minShake: 0.0,                 // Terima walaupun statik
        botDetectionSensitivity: 0.0,  // Matikan AI Bot Detector
        thresholdAmount: 0.0,          // Terima sebarang input
        
        minSolveTime: Duration.zero,   // Laju pun takpe
        jamCooldown: Duration(seconds: 2), // Reset cepat kalau fail
        maxAttempts: 99,               // Unlimited try
        
        // ✅ SENSOR HIDUP (Untuk UI visual je, bukan untuk block user)
        enableSensors: true,            
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSuccess() {
    print("✅ PASSWORD BETUL!");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("ACCESS GRANTED"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onFail() {
    print("❌ PASSWORD SALAH!");
    HapticFeedback.heavyImpact();
  }

  void _onJammed() {
    print("⛔ SYSTEM JAMMED");
    HapticFeedback.vibrate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle, size: 40, color: Colors.orange),
              const SizedBox(height: 10),
              const Text("DEV MODE: SECURITY DISABLED", style: TextStyle(color: Colors.orange, letterSpacing: 2)),
              const SizedBox(height: 50),
              
              // WIDGET UI ASAL (V3.5)
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
