// 📱 MAIN ENTRY POINT - "REALISTIC MODE & WYSIWYS"
// Status: FINAL POLISHED (NO DUPLICATES)
// Features: Dynamic Transaction Display + Neon Matrix Green Numbers

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Kunci orientasi ke Portrait sahaja (Wajib untuk sensor)
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
      title: 'Z-KINETIC PRODUCTION',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: Colors.blueAccent,
      ),
      // 🔥 DATA SIMULASI (Hacker vs Normal)
      // Cuba ubah nilai di sini untuk lihat perubahan di skrin kunci
      home: const LockScreen(
        transactionType: "TRANSFER FUNDS",
        amount: "RM 50,000.00",       // 💰 Nilai Besar
        recipientName: "ALI BIN AHMAD", // 👤 Penerima
        accountNumber: "1234-5678-9012",
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  // ✅ DATA DINAMIK (WYSIWYS)
  final String transactionType;
  final String amount;
  final String recipientName;
  final String accountNumber;

  const LockScreen({
    super.key,
    this.transactionType = "TRANSACTION",
    this.amount = "RM 0.00",
    this.recipientName = "Unknown",
    this.accountNumber = "0000-0000",
  });

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
          // 🔑 PASSWORD RAHSIA
          secret: [1, 7, 3, 9, 2],
          
          // 🎯 REALISTIC MODE SETTINGS
          minShake: 0.4, 
          botDetectionSensitivity: 0.25,  
          thresholdAmount: 0.25, 
          minSolveTime: Duration(milliseconds: 600),
          maxAttempts: 5,  
          jamCooldown: Duration(seconds: 10), 
          enableSensors: true,
          
          // 🔐 TELEMETRY CREDENTIALS
          clientId: 'CRYPTER_REALISTIC_DEMO',
          clientSecret: 'a7f3d8e2c9b1f4a6e8d3c7b2f9a4e6d8c1b3f7a9e2d4c8b6f1a3e7d9',
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
                Text("ERROR: $_errorMessage", style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() { _errorMessage = null; _isInitialized = false; });
                    _initializeController();
                  },
                  child: const Text("RETRY"),
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
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
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
                // 🎚️ BANNER (MATRIX STYLE)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF00).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00FF00), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF00).withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, size: 24, color: Color(0xFF00FF00)),
                      SizedBox(width: 8),
                      Text(
                        "BIOMETRIC ACTIVE",
                        style: TextStyle(
                          color: Color(0xFF00FF00),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 🚨 WYSIWYS ALERT BOX (INTERACTIVE)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 15),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                          SizedBox(width: 10),
                          Text("VERIFY TRANSACTION", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.transactionType, style: TextStyle(color: Colors.red.shade300, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, fontFamily: 'monospace')),
                            const SizedBox(height: 8),
                            // 🔥 DATA DINAMIK 1: AMOUNT
                            Text(widget.amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text("TO: ", style: TextStyle(color: Colors.red.shade300, fontSize: 11, fontFamily: 'monospace')),
                                // 🔥 DATA DINAMIK 2: ACCOUNT
                                Text(widget.accountNumber, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // 🔥 DATA DINAMIK 3: NAME
                            Text(widget.recipientName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 🎮 CRYPTEX LOCK WIDGET
                CryptexLock(
                  controller: _controller,
                  onSuccess: _onSuccess,
                  onFail: _onFail,
                  onJammed: _onJammed,
                ),
                
                const SizedBox(height: 30),
                
                // 📊 MATRIX DEBUG INFO (Hijau Menyala untuk Nombor)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00FF00).withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildMatrixDebugRow("TARGET", "1-7-3-9-2"),
                      const SizedBox(height: 8),
                      _buildMatrixDebugRow("ATTEMPTS", "${_controller.failedAttempts}/5"),
                      const SizedBox(height: 8),
                      _buildMatrixDebugRow("STATE", _controller.state.toString().split('.').last),
                      
                      const Divider(height: 20, color: Colors.white10),
                      
                      // Progress Bars dengan Nombor Hijau
                      _buildMatrixBar("MOTION", _controller.motionConfidence),
                      const SizedBox(height: 10),
                      _buildMatrixBar("PATTERN", _controller.liveConfidence),
                      const SizedBox(height: 10),
                      _buildMatrixBar("TOUCH", _controller.touchConfidence),
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

  // 🔥 FUNGSI UTAMA: MENUKAR NOMBOR JADI HIJAU MATRIX + GLOW
  Widget _buildMatrixDebugRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label kekal Hijau Pudar
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF00FF00).withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
        // Nilai (Nombor) jadi HIJAU MENYALA (NEON)
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF00FF00), // ✅ Matrix Green
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 1,
            shadows: [
              Shadow(
                color: Color(0xFF00FF00),
                blurRadius: 8, // ✅ Glow Effect
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🔥 FUNGSI BAR: NOMBOR PERATUSAN JUGA HIJAU
  Widget _buildMatrixBar(String label, double value) {
    final percentage = (value * 100).toStringAsFixed(0);
    // Warna bar berubah ikut nilai (Merah/Kuning/Hijau)
    final barColor = _getMatrixColor(value);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: barColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
            Row(
              children: [
                // Nombor Peratusan -> HIJAU MATRIX + GLOW (Tak kira warna bar apa)
                Text(
                  "$percentage%",
                  style: const TextStyle(
                    color: Color(0xFF00FF00), // ✅ Force Matrix Green
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    shadows: [
                      Shadow(color: Color(0xFF00FF00), blurRadius: 5),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getMatrixStatus(value),
                  style: TextStyle(
                    color: barColor.withOpacity(0.7),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: barColor.withOpacity(0.3), width: 1),
          ),
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                boxShadow: [
                  BoxShadow(color: barColor.withOpacity(0.6), blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getMatrixColor(double value) {
    if (value >= 0.6) return const Color(0xFF00FF00); // Green
    if (value >= 0.3) return const Color(0xFFFFFF00); // Yellow
    return const Color(0xFFFF0000); // Red
  }

  String _getMatrixStatus(double value) {
    if (value >= 0.6) return "[OK]";
    if (value >= 0.3) return "[--]";
    return "[!!]";
  }
}
