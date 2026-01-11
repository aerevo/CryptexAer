import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Pastikan import ini betul ikut struktur folder Kapten
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart'; 

void main() {
  // Pastikan binding initialize sebelum panggil native code
  WidgetsFlutterBinding.ensureInitialized();
  
  // Paksa Portrait Mode (Security App biasanya portrait)
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
      title: 'Z-KINETIC V5',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: const Color(0xFF00FFFF), // Cyan neon
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
    
    // ═══════════════════════════════════════════════════════
    // 🔧 CONFIGURATION: HUMAN FRIENDLY (SWEET SPOT)
    // ═══════════════════════════════════════════════════════
    _controller = ClaController(
      const ClaConfig(
        secret: [1, 7, 3, 9, 2], // Password Kapten
        
        // 1. Min Shake: 0.02 (Sangat rendah)
        // Kalau letak phone atas meja & ketuk skrin, gegaran ~0.03.
        // Jadi ini cukup untuk detect 'hidup' tanpa perlu pegang.
        minShake: 0.02,                 
        
        // 2. Sensitiviti Bot: 0.2 (Rendah)
        // Kurang paranoid. Dia akan lebih "bersangka baik" pada user.
        botDetectionSensitivity: 0.2,   
        
        // 3. Threshold: 0.2
        // Scroll roda sikit pun dah dikira "input valid".
        thresholdAmount: 0.2,           
        
        minSolveTime: Duration(milliseconds: 200), 
        jamCooldown: Duration(seconds: 10),
        maxAttempts: 5,
        
        // ⚠️ SENSOR WAJIB HIDUP (Untuk Production)
        enableSensors: true,            
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Callback: Bila Berjaya
  void _onSuccess() {
    print("✅ ACCESS GRANTED");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("ACCESS GRANTED: WELCOME CAPTAIN AER"),
        backgroundColor: Color(0xFF00FF88),
        duration: Duration(seconds: 2),
      ),
    );
    // Di sini navigate ke Home Page
  }

  // Callback: Bila Salah Password
  void _onFail() {
    print("⚠️ ACCESS DENIED");
    HapticFeedback.heavyImpact();
  }

  // Callback: Bila Kena Lock (Bot/Spam)
  void _onJammed() {
    print("⛔ SYSTEM LOCKDOWN");
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
              // Header Icon
              Icon(Icons.shield_outlined, size: 40, color: Colors.cyan.withOpacity(0.7)),
              const SizedBox(height: 20),
              
              // Title
              const Text(
                "Z-KINETIC V5",
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 4,
                  color: Colors.white
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "IDENTITY VERIFICATION",
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.white.withOpacity(0.5), 
                  fontSize: 10,
                  letterSpacing: 2
                ),
              ),
              const SizedBox(height: 50),
              
              // 🔐 THE LOCK WIDGET
              CryptexLock(
                controller: _controller,
                onSuccess: _onSuccess,
                onFail: _onFail,
                onJammed: _onJammed,
              ),
              
              const SizedBox(height: 50),
              
              // Footer
              Text(
                "SECURE ENVIRONMENT",
                style: TextStyle(color: Colors.grey[800], fontSize: 9, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
