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
      title: 'Z-KINETIC REALISTIC',
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
          
          // 🎯 REALISTIC MODE: Security ON + Human-Friendly
          
          // 📱 MOTION DETECTION (Light Touch)
          minShake: 0.4,  // ✅ Very light - natural phone movement
          // Tips: Angkat phone dari meja = cukup
          
          // 🤖 BOT DETECTION (Balanced)
          botDetectionSensitivity: 0.25,  // ✅ Catches bots, allows humans
          // Tips: Just interact naturally - no special effort needed
          
          // ⚖️ CONFIDENCE THRESHOLD (Forgiving)
          thresholdAmount: 0.25,  // ✅ Low requirement
          // Tips: Normal behavior passes easily
          
          // ⏱️ SOLVE TIME (Realistic)
          minSolveTime: Duration(milliseconds: 600),  // ✅ 0.6s minimum
          // Tips: Don't instant submit - pause sikit je
          
          // 🔒 LOCKOUT POLICY (Fair)
          maxAttempts: 5,  // ✅ 5 chances
          jamCooldown: Duration(seconds: 10),  // ✅ 10 sec cooldown
          
          // 🔧 SENSOR (Always On)
          enableSensors: true,
          
          // 🔐 TELEMETRY
          clientId: 'CRYPTER_REALISTIC',
          clientSecret: 'captain_aer_testing_secret_2026',
        ),
      );
      
      setState(() {
        _isInitialized = true;
      });
      
      print("✅ Controller initialized (REALISTIC MODE)");
      
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
    print("   Threat: ${_controller.threatMessage}");
    HapticFeedback.heavyImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "❌ WRONG PIN (${_controller.failedAttempts}/5)",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_controller.threatMessage.isNotEmpty)
              Text(
                _controller.threatMessage,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
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
        duration: const Duration(seconds: 3),
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
                // 🎯 REALISTIC MODE BANNER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, size: 24, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text(
                        "REALISTIC SECURITY",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                const Text(
                  "Smart Protection • Easy Access",
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
                        Colors.green.withOpacity(0.1),
                        Colors.blue.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tips_and_updates, color: Colors.yellow, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "UNLOCK NATURALLY",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTip("🎯", "Target: 1-7-3-9-2"),
                      _buildTip("📱", "Angkat phone naturally (motion auto-detect)"),
                      _buildTip("⏱️", "Take ~1 second to set wheels"),
                      _buildTip("✨", "That's it! System detects human behavior"),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 📊 DEBUG INFO (Enhanced)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getHealthColor().withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "SECURITY STATUS",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getHealthColor().withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getHealthStatus(),
                              style: TextStyle(
                                color: _getHealthColor(),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: Colors.white24),
                      _buildDebugRow("Target PIN:", "1-7-3-9-2"),
                      const SizedBox(height: 8),
                      _buildDebugRow("Attempts:", "${_controller.failedAttempts}/5"),
                      const SizedBox(height: 8),
                      _buildDebugRow("State:", _controller.state.toString().split('.').last),
                      const SizedBox(height: 8),
                      _buildDebugRowWithBar("Motion:", _controller.motionConfidence),
                      const SizedBox(height: 8),
                      _buildDebugRowWithBar("Touch:", _controller.touchConfidence),
                      const SizedBox(height: 8),
                      _buildDebugRowWithBar("Confidence:", _controller.liveConfidence),
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

  Widget _buildDebugRowWithBar(String label, double value) {
    final percentage = (value * 100).toStringAsFixed(0);
    final color = value > 0.5 ? Colors.green : (value > 0.2 ? Colors.orange : Colors.red);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            Text(
              "$percentage%",
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Color _getHealthColor() {
    final motion = _controller.motionConfidence;
    final touch = _controller.touchConfidence;
    final avg = (motion + touch) / 2;
    
    if (avg > 0.5) return Colors.green;
    if (avg > 0.2) return Colors.orange;
    return Colors.red;
  }

  String _getHealthStatus() {
    final motion = _controller.motionConfidence;
    final touch = _controller.touchConfidence;
    final avg = (motion + touch) / 2;
    
    if (avg > 0.5) return "HEALTHY";
    if (avg > 0.2) return "MODERATE";
    return "LOW";
  }
}
