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
        primaryColor: Colors.blueAccent,
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
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    try {
      _controller = ClaController(
        const ClaConfig(
          secret: [1, 7, 3, 9, 2],
          
          // 🔓 GOD MODE: Security Features Disabled
          minShake: 0.0,
          botDetectionSensitivity: 0.0,
          thresholdAmount: 0.0,
          minSolveTime: Duration.zero,
          jamCooldown: Duration(seconds: 2),
          maxAttempts: 99,
          enableSensors: true,
          
          // ✅ CUSTOM SECRET (Bypass default check)
          clientId: 'CRYPTER_DEMO',
          clientSecret: 'captain_aer_testing_secret_2026', // 🔥 CHANGED!
        ),
      );
      
      setState(() {
        _isInitialized = true;
      });
      
      print("✅ Controller initialized successfully");
      
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = e.toString();
      });
      print("❌ Controller initialization failed: $e");
      print("Stack trace: $stackTrace");
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onSuccess() {
    print("✅ PASSWORD CORRECT!");
    HapticFeedback.mediumImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "🔓 ACCESS GRANTED",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onFail() {
    print("❌ PASSWORD INCORRECT!");
    HapticFeedback.heavyImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "❌ WRONG PIN (${_controller.failedAttempts}/99)",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onJammed() {
    print("⛔ SYSTEM JAMMED");
    HapticFeedback.vibrate();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "⛔ TOO MANY ATTEMPTS - LOCKED",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.deepOrange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 ERROR STATE WITH WORKING RETRY
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  "INITIALIZATION ERROR",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () {
                    print("🔄 Retry button pressed");
                    setState(() {
                      _errorMessage = null;
                      _isInitialized = false;
                    });
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _initializeController();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("RETRY INITIALIZATION"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "💡 Solution: Change clientSecret in code",
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ⏳ LOADING STATE
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blueAccent),
              SizedBox(height: 20),
              Text(
                "Initializing Security System...",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ MAIN UI
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔧 DEV MODE BANNER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.build_circle, size: 24, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        "DEV MODE",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                const Text(
                  "Security Disabled for Testing",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                
                const SizedBox(height: 40),
                
                // 🎮 CRYPTEX LOCK WIDGET
                CryptexLock(
                  controller: _controller,
                  onSuccess: _onSuccess,
                  onFail: _onFail,
                  onJammed: _onJammed,
                ),
                
                const SizedBox(height: 40),
                
                // 📊 DEBUG INFO
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDebugRow("Target PIN:", "1-7-3-9-2"),
                      const SizedBox(height: 8),
                      _buildDebugRow("Failed Attempts:", "${_controller.failedAttempts}"),
                      const SizedBox(height: 8),
                      _buildDebugRow("State:", _controller.state.toString().split('.').last),
                      const SizedBox(height: 8),
                      _buildDebugRow("Max Attempts:", "99 (God Mode)"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
