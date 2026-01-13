// 🛡️ Z-KINETIC HYBRID - CYAN UI + MATRIX NUMBERS
// Status: FINAL VISUAL FIX
// Features: UI Cyan (Safe) + Data Numbers Matrix Green (John Wick Style)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart';
import 'dart:async'; // Untuk simulasi koordinat "bermain-main"

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
      title: 'Z-KINETIC HYBRID',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        // 🔥 UI UTAMA KEKAL CYAN (BIRU NEON)
        primaryColor: Colors.cyanAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.cyanAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const SystemSelectorPage(),
    );
  }
}

// ==========================================
// 1️⃣ PAGE PEMILIHAN SISTEM
// ==========================================
class SystemSelectorPage extends StatefulWidget {
  const SystemSelectorPage({super.key});

  @override
  State<SystemSelectorPage> createState() => _SystemSelectorPageState();
}

class _SystemSelectorPageState extends State<SystemSelectorPage> {
  String _selectedSystem = "DEFENSE_GRID_ALPHA"; 
  
  final Map<String, IconData> _systemIcons = {
    "DEFENSE_GRID_ALPHA": Icons.shield,
    "CRYPTO_COLD_STORAGE": Icons.currency_bitcoin,
    "SOCIAL_ADMIN_PANEL": Icons.public,
    "CLONE_PROTOCOL_V2": Icons.fingerprint,
  };

  void _initiateSequence({bool isCompromised = false}) {
    final String targetSystem = isCompromised ? "UNKNOWN_SERVER_RUSSIA" : _selectedSystem;
    final String securityLevel = isCompromised ? "⚠️ CRITICAL RISK" : "LEVEL 5 (MAX)";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LockScreen(
          systemName: targetSystem,
          securityLevel: securityLevel,
          isCompromised: isCompromised,
          onUnlockSuccess: () {
            _showAccessGranted(targetSystem);
          },
        ),
      ),
    );
  }

  void _showAccessGranted(String system) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.cyanAccent)),
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.cyanAccent, size: 28),
            SizedBox(width: 10),
            Text("ACCESS GRANTED", style: TextStyle(color: Colors.cyanAccent)),
          ],
        ),
        content: Text(
          "Uplink established to: $system\nSession encryption: AES-256",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("ENTER SYSTEM", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Z-KINETIC GATEWAY")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hub, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 20),
              const Text(
                "SELECT TARGET SYSTEM",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.cyanAccent),
              ),
              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.cyanAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSystem,
                    dropdownColor: Colors.black,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                    isExpanded: true,
                    items: _systemIcons.keys.map((String key) {
                      return DropdownMenuItem<String>(
                        value: key,
                        child: Row(
                          children: [
                            Icon(_systemIcons[key], size: 20, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text(key, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedSystem = newValue!;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 40),

              ElevatedButton.icon(
                onPressed: () => _initiateSequence(isCompromised: false),
                icon: const Icon(Icons.vpn_key, color: Colors.black),
                label: const Text("INITIATE SECURITY SEQUENCE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent, // 🔥 BUTANG KEKAL CYAN
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),

              const Spacer(),

              OutlinedButton.icon(
                onPressed: () => _initiateSequence(isCompromised: true),
                icon: const Icon(Icons.warning, color: Colors.red),
                label: const Text("SIMULATE SIGNAL HIJACK", style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2️⃣ PAGE KEDUA: LOCK SCREEN (HYBRID MATRIX)
// ==========================================
class LockScreen extends StatefulWidget {
  final String systemName;
  final String securityLevel;
  final bool isCompromised; 
  final VoidCallback? onUnlockSuccess;

  const LockScreen({
    super.key,
    required this.systemName,
    required this.securityLevel,
    this.isCompromised = false,
    this.onUnlockSuccess,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  Timer? _matrixTimer;
  String _randomCoord = "34.0522° N"; // Dummy coord untuk efek visual

  @override
  void initState() {
    super.initState();
    _initializeController();
    // Timer untuk buat koordinat "bermain-main"
    _matrixTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _randomCoord = "${(34 + (timer.tick % 100) * 0.01).toStringAsFixed(4)}° N";
        });
      }
    });
  }

  void _initializeController() {
    try {
      _controller = ClaController(
        const ClaConfig(
          secret: [1, 7, 3, 9, 2],
          minShake: 0.4, 
          botDetectionSensitivity: 0.25,  
          thresholdAmount: 0.25, 
          minSolveTime: Duration(milliseconds: 600),
          maxAttempts: 5,  
          jamCooldown: Duration(seconds: 10), 
          enableSensors: true,
          clientId: 'Z_KINETIC_HYBRID',
          clientSecret: 'cyan_green_mix',
        ),
      );
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  void dispose() {
    if (_isInitialized) _controller.dispose();
    _matrixTimer?.cancel();
    super.dispose();
  }

  void _onSuccess() {
    HapticFeedback.mediumImpact();
    if (widget.onUnlockSuccess != null) {
      widget.onUnlockSuccess!();
    } else {
      Navigator.pop(context);
    }
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ ACCESS DENIED (${_controller.failedAttempts}/5)"), backgroundColor: Colors.red),
    );
  }

  void _onJammed() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("⛔ TERMINAL LOCKED FOR ${_controller.remainingLockoutSeconds}s"), backgroundColor: Colors.deepOrange),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));
    }

    // 🔥 LOGIK WARNA: 
    // UI Utama = Cyan (Safe) atau Merah (Hacked).
    // Nombor Data = Sentiasa Hijau Matrix (melainkan Hacked, data pun merah sebab corrupt).
    final Color uiColor = widget.isCompromised ? Colors.red : Colors.cyanAccent;
    final Color dataColor = widget.isCompromised ? Colors.red : const Color(0xFF00FF00); // HIJAU MATRIX

    return Scaffold(
      appBar: AppBar(
        title: Text("SECURITY CLEARANCE: ${widget.isCompromised ? 'FAILED' : 'ACTIVE'}", 
          style: TextStyle(color: uiColor, fontSize: 14, fontFamily: 'monospace')),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                // ⚠️ ALERT BOX (WARNA IKUT UI - CYAN/MERAH)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: uiColor, width: 2), 
                    boxShadow: [
                      BoxShadow(color: uiColor.withOpacity(0.2), blurRadius: 20, spreadRadius: 2), 
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(widget.isCompromised ? Icons.gpp_bad : Icons.gpp_good, color: uiColor, size: 28),
                          const SizedBox(width: 12),
                          Text("ACCESS REQUEST", style: TextStyle(color: uiColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace', letterSpacing: 1)),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 30),
                      
                      const Text("TARGET SYSTEM:", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(
                        widget.systemName, 
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      const Text("SECURITY PROTOCOL:", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(
                        widget.securityLevel,
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'monospace', backgroundColor: widget.isCompromised ? Colors.red.withOpacity(0.3) : null),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // 🎮 CRYPTEX LOCK WIDGET
                CryptexLock(
                  controller: _controller,
                  onSuccess: _onSuccess,
                  onFail: _onFail,
                  onJammed: _onJammed,
                ),
                
                const SizedBox(height: 30),

                // 📊 MATRIX TELEMETRY BOX
                // 🔥 INI BAHAGIAN YG KAPTEN NAK HIJAU ("Nombor2 bermain bawah coord")
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    // Border luar kekal Cyan (matching UI atas)
                    border: Border.all(color: uiColor.withOpacity(0.5), width: 1),
                  ),
                  child: Column(
                    children: [
                      // Header Label (Cyan/Merah)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("LIVE TELEMETRY", style: TextStyle(color: uiColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          Icon(Icons.data_usage, color: uiColor, size: 16),
                        ],
                      ),
                      const Divider(color: Colors.white12),
                      
                      // 🔥 COORD (YANG BERMAIN-MAIN)
                      _buildMatrixRow("GEO-COORD", _randomCoord, uiColor, dataColor),
                      const SizedBox(height: 8),
                      // 🔥 TARGET (NOMBOR HIJAU)
                      _buildMatrixRow("TARGET PIN", "1-7-3-9-2", uiColor, dataColor),
                      const SizedBox(height: 8),
                      // 🔥 MOTION (NOMBOR HIJAU)
                      _buildMatrixRow("MOTION SENS", "${(_controller.motionConfidence * 100).toInt()}%", uiColor, dataColor),
                      const SizedBox(height: 8),
                      // 🔥 PATTERN (NOMBOR HIJAU)
                      _buildMatrixRow("PATTERN MATCH", "${(_controller.liveConfidence * 100).toInt()}%", uiColor, dataColor),
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

  // 🛠️ FUNGSI BINA ROW: LABEL (CYAN) vs VALUE (MATRIX GREEN)
  Widget _buildMatrixRow(String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label ikut tema UI (Cyan)
        Text(
          label, 
          style: TextStyle(
            color: labelColor.withOpacity(0.7), 
            fontSize: 12, 
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
        // Value "BERMAIN-MAIN" jadi MATRIX GREEN (0xFF00FF00) + GLOW
        Text(
          value,
          style: TextStyle(
            color: valueColor, // 🔥 INI KEKUNCI DIA (HIJAU MATRIX)
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            fontFamily: 'monospace', 
            letterSpacing: 1.5,
            shadows: [
              Shadow(color: valueColor, blurRadius: 10), // Glow Effect
            ],
          ),
        ),
      ],
    );
  }
}
