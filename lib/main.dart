import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'z_kinetic_sdk.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MAIN.DART - Z-KINETIC CLIENT APP (ENTERPRISE EDITION)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Fail ini telah dikonfigurasikan untuk berhubung terus ke 
// Pelayan Utama (Fasa 2) menggunakan protokol keselamatan HMAC.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Mengunci orientasi peranti untuk kestabilan sensor fizik
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ✅ INITIALIZATION KELAS-S (ADMIN PRIVILEGE)
  // Konfigurasi ini menyelaraskan Flutter dengan ekosistem Web Tuan
  ZKinetic.initialize(
    appId: 'admin_aer', 
    serverUrl: 'https://zticketapp-dxtcyy6wma-as.a.run.app',
    customImageUrl: 'https://z-kinetic.web.app/sdk/z_wheel3.png',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Z-KINETIC SECURITY',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ZKineticController _sdkController = ZKineticController();
  bool _showSecurityWidget = false;

  void _onVerificationComplete(double physicsScore) {
    setState(() => _showSecurityWidget = false);
    
    // Protokol maklum balas selepas pengesahan biometrik
    if (physicsScore >= 0.4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PENGESAHAN LULUS: Skor Fizik $physicsScore'),
          backgroundColor: Colors.emerald(600),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PENGESAHAN GAGAL: Aktiviti Bot Dikesan'),
          backgroundColor: Colors.red(600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── BACKGROUND LAYER (CITADEL) ─────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF1E293B), Colors.black],
                center: Alignment.center,
                radius: 1.2,
              ),
            ),
          ),

          // ─── INTERFACE UTAMA ────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 80, color: Color(0xFF0EA5E9)),
                const SizedBox(height: 20),
                const Text(
                  'Z-KINETIC PROTECTED',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => setState(() => _showSecurityWidget = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 10,
                  ),
                  child: const Text(
                    'JALANKAN UJIAN BIOMETRIK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Z-KINETIC SDK OVERLAY (THE CRYPTEX) ────────────
          if (_showSecurityWidget)
            ZKineticWidgetProdukB(
              controller: _sdkController,
              onComplete: _onVerificationComplete,
              onCancel: () => setState(() => _showSecurityWidget = false),
            ),
        ],
      ),
    );
  }
}
