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
      title: 'Z-KINETIC BALANCED',
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
          
          // 🎚️ BALANCED MODE: Security Enabled but Reasonable
          
          // 📱 MOTION DETECTION (Gentle)
          minShake: 1.2,  // ✅ Require SOME movement (ringan je)
          // Tips: Goyangkan phone sikit masa unlock (natural motion)
          
          // 🤖 BOT DETECTION (Low Sensitivity)
          botDetectionSensitivity: 0.6,  // ✅ Detect extreme bot behavior only
          // Tips: Touch screen naturally, don't rush
          
          // ⚖️ CONFIDENCE THRESHOLD (Relaxed)
          thresholdAmount: 0.3,  // ✅ Low bar (easy to pass)
          // Tips: Just interact normally
          
          // ⏱️ SOLVE TIME (Moderate)
          minSolveTime: Duration(seconds: 2),  // ✅ At least 1 second
          // Tips: Don't instant submit (too fast = suspicious)
          
          // 🔒 LOCKOUT POLICY (Fair)
          maxAttempts: 5,  // ✅ 5 chances (reasonable)
          jamCooldown: Duration(seconds: 10),  // ✅ 10 sec cooldown
          
          // 🔧 SENSOR (Always On)
          enableSensors: true,
          
          // 🔐 TELEMETRY
          clientId: 'CRYPTER_BALANCED',
          clientSecret: 'captain_aer_testing_secret_2026',
        ),
      );
      
      setState(() {
        _isInitialized = true;
      });
      
      print("✅ Controller initialized (BALANCED MODE)");
      
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
          "❌ WRONG PIN (${_controller.failedAttempts}/5)",
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
    
    final remaining = _controller.remainingLockoutSeconds;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "⛔ LOCKED FOR $remaining SECONDS",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.deepOrange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 ERROR STATE
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
                    setState(() {
                      _errorMessage = null;
                      _isInitialized = false;
                    });
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _initializeController();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("RETRY"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
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
                // 🎚️ BALANCED MODE BANNER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 24, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        "BALANCED SECURITY",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                const Text(
                  "Human-Friendly Protection Enabled",
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
                
                // 💡 TIPS BOX
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.1),
                        Colors.purple.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, color: Colors.yellow, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "HOW TO UNLOCK SUCCESSFULLY",
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTip("1️⃣", "Set PIN to: 1-7-3-9-2"),
                      _buildTip("2️⃣", "Goyangkan phone SIKIT (natural motion)"),
                      _buildTip("3️⃣", "Don't rush - take at least 1-2 seconds"),
                      _buildTip("4️⃣", "Touch screen normally (like human)"),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
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
                      _buildDebugRow("Attempts:", "${_controller.failedAttempts}/5"),
                      const SizedBox(height: 8),
                      _buildDebugRow("State:", _controller.state.toString().split('.').last),
                      const SizedBox(height: 8),
                      _buildDebugRow("Motion:", "${(_controller.motionConfidence * 100).toStringAsFixed(0)}%"),
                      const SizedBox(height: 8),
                      _buildDebugRow("Touch:", "${(_controller.touchConfidence * 100).toStringAsFixed(0)}%"),
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

  Widget _buildTip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
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


