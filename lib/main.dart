// 🛡️ Z-KINETIC HERO EDITION
// Status: INTELLIGENT DETECTION
// Features: Passive Safety / Active Threat Warning + Hero Report Protocol

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; 
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
      title: 'Z-KINETIC HERO',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: Colors.cyanAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      // ⚠️ TUKAR 'isHacked' KE 'true' UNTUK TEST JADI HERO
      // ⚠️ TUKAR KE 'false' UNTUK TEST SITUASI SELAMAT
      home: const LockScreen(
        systemName: "TRANSFER FUNDS",
        originalAmount: "RM 50.00",
        // 🔥 Cuba tukar ini jadi 'true' untuk tengok amaran merah keluar!
        isHacked: true, 
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  final String systemName;
  final String originalAmount;
  final bool isHacked; // 🔥 Logik Pengesanan Automatik

  const LockScreen({
    super.key,
    required this.systemName,
    required this.originalAmount,
    this.isHacked = false, // Default selamat
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;
  bool _isInitialized = false;
  Timer? _matrixTimer;
  String _randomCoord = "00.0000° N";

  @override
  void initState() {
    super.initState();
    _initializeController();
    
    // Animasi Sensor Matrix
    _matrixTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          double lat = 34 + (timer.tick % 99) * 0.013;
          double long = 118 + (timer.tick % 88) * 0.017;
          _randomCoord = "${lat.toStringAsFixed(4)}° N, ${long.toStringAsFixed(4)}° W";
        });
      }
    });
  }

  void _initializeController() {
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
        clientId: 'Z_KINETIC_HERO',
        clientSecret: 'hero_v1',
      ),
    );
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _matrixTimer?.cancel();
    super.dispose();
  }

  // 🦸‍♂️ FUNGSI HERO: CANCEL & REPORT
  void _handleReportAndCancel() {
    HapticFeedback.heavyImpact(); // Gegar kuat tanda bahaya
    
    // 1. Simpan Log (Simulasi)
    print("🚨 REPORT GENERATED: MANIPULATION DETECTED");
    
    // 2. Papar Dialog Hero
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.white),
            SizedBox(width: 10),
            Text("REPORT GENERATED", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Laporan pemesongan data telah dijana.\n\n"
          "Fail ini telah dihantar ke terminal Kapten Aer untuk tindakan lanjut ke pihak Bank.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              Navigator.pop(context); // Keluar dari screen (Cancel transaction)
            },
            child: const Text("CLOSE & SECURE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onSuccess() {
    if (widget.isHacked) {
      // Kalau user degil nak unlock juga masa hacked
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ WARNING: YOU AUTHORIZED A COMPROMISED TRANSACTION"), backgroundColor: Colors.red),
      );
    } else {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ACCESS GRANTED"), backgroundColor: Colors.green),
      );
    }
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("INVALID CREDENTIALS (${_controller.failedAttempts}/5)"), backgroundColor: Colors.red),
    );
  }

  void _onJammed() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("LOCKED: ${_controller.remainingLockoutSeconds}s"), backgroundColor: Colors.deepOrange),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));
    }

    const Color uiColor = Colors.cyanAccent;
    const Color dataColor = Color(0xFF00FF00); // Matrix Green

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("SECURE GATEWAY", style: TextStyle(color: uiColor, fontSize: 14, fontFamily: 'monospace', letterSpacing: 2)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                // 🔥 LOGIK INTELLIGENCE: TENTUKAN PAPARAN
                if (widget.isHacked)
                  _buildHackedNotice() // 🔴 Paparan Bising (Bahaya)
                else
                  _buildSafeNotice(), // 🟢 Paparan Senyap (Selamat)
                
                const SizedBox(height: 40),

                // 2️⃣ CRYPTEX LOCK (ALAT UTAMA)
                // Jika Hacked, kita boleh disable atau biarkan user buat pilihan bodoh.
                // Di sini saya biarkan aktif tapi ada amaran merah.
                CryptexLock(
                  controller: _controller,
                  onSuccess: _onSuccess,
                  onFail: _onFail,
                  onJammed: _onJammed,
                ),

                const SizedBox(height: 40),

                // 3️⃣ SENSOR ARRAY (Matrix Green)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: uiColor.withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("LIVE SENSORS", style: TextStyle(color: uiColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          Icon(Icons.query_stats, color: uiColor, size: 14),
                        ],
                      ),
                      const Divider(color: Colors.white12),

                      _buildSimpleRow("GEO-COORD", _randomCoord, uiColor, dataColor),
                      const SizedBox(height: 5),
                      _buildSimpleRow("TARGET PIN", "1-7-3-9-2", uiColor, dataColor),
                      
                      const Divider(color: Colors.white12, height: 15),

                      _buildSensorBar("MOTION FLUX", _controller.motionConfidence, uiColor, dataColor),
                      const SizedBox(height: 10),
                      _buildSensorBar("PATTERN MATCH", _controller.liveConfidence, uiColor, dataColor),
                      const SizedBox(height: 10),
                      _buildSensorBar("TOUCH PRESS", _controller.touchConfidence, uiColor, dataColor),
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

  // 🟢 PAPARAN SELAMAT (SENYAP)
  Widget _buildSafeNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Text(
            "100% SECURE. PROCEED TO UNLOCK.",
            style: TextStyle(color: Colors.green.shade300, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  // 🔴 PAPARAN HACKED (BISING & HERO ACTION)
  Widget _buildHackedNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 10),
              Text("DATA MANIPULATION DETECTED!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "AMARAN: Jumlah asal anda (RM 50) telah diubah kepada RM 50,000 oleh pihak ketiga!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 20),
          
          // 🔥 BUTANG HERO
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleReportAndCancel,
              icon: const Icon(Icons.report, color: Colors.white),
              label: const Text("CANCEL & REPORT TO HQ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildSimpleRow(String label, String value, Color uiColor, Color dataColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: uiColor.withOpacity(0.6), fontSize: 10, fontFamily: 'monospace')),
        Text(value, style: TextStyle(color: dataColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', shadows: [Shadow(color: dataColor, blurRadius: 5)])),
      ],
    );
  }

  Widget _buildSensorBar(String label, double value, Color uiColor, Color dataColor) {
    final percentage = (value * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: uiColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            Text("$percentage%", style: TextStyle(color: dataColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', shadows: [Shadow(color: dataColor, blurRadius: 5)])),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(color: uiColor, boxShadow: [BoxShadow(color: uiColor.withOpacity(0.5), blurRadius: 4)]),
            ),
          ),
        ),
      ],
    );
  }
}
