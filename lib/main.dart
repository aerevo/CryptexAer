import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'z_kinetic_sdk.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MAIN.DART - CLIENT APP (DEMO)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Fail ini adalah contoh cara client guna SDK.
// Tak perlu tahu pasal sensor, server, atau logic.
// Panggil ZKineticWidgetProdukB je!
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ✅ Wajib panggil ini SEBELUM runApp()
  // appId = public identifier yang Captain bagi kepada klien
  // Secret API Key TIDAK diletakkan di sini — ia kekal di server sahaja
  ZKinetic.initialize(
  appId: 'admin_aer',
  customImageUrl: 'https://z-kinetic.web.app/sdk/z_wheel3.png', // TAMBAH SINI
);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFFF5722),
        useMaterial3: true,
      ),
      home: const ClientAppDemo(),
    );
  }
}

class ClientAppDemo extends StatefulWidget {
  const ClientAppDemo({super.key});

  @override
  State<ClientAppDemo> createState() => _ClientAppDemoState();
}

class _ClientAppDemoState extends State<ClientAppDemo> {
  bool _showSecurityWidget = false;

  // ✅ WidgetController() — tiada appId di sini
  // appId diambil secara automatik dari ZKinetic.initialize() di atas
  final WidgetController _sdkController = WidgetController();

  void _onVerificationComplete(bool success) {
    setState(() => _showSecurityWidget = false);

    if (success) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.green.shade800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '✅ User Verified!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Access granted. Processing...',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('PROCEED', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.red.shade900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '⚠️ Pengesahan Gagal',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Terlalu banyak percubaan tidak berjaya. Sila cuba semula.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cuba Semula', style: TextStyle(color: Colors.white)),
            ),
          ],
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
          // ─── CLIENT APP UI ───────────────────────────────────
          Center(
            child: ElevatedButton(
              onPressed: () => setState(() => _showSecurityWidget = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                'LAUNCH SECURITY CHECK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          // ─── Z-KINETIC SDK OVERLAY ───────────────────────────
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
