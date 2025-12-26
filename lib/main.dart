import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cryptex_lock/cryptex_lock.dart';

void main() {
  // 1. KUNCI ORIENTASI (Bank Grade Standard)
  // Aplikasi kewangan tidak boleh pusing-pusing (landscape) untuk elak UI glitch/overlay attack.
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
      debugShowCheckedModeBanner: false, // Hilangkan tanda DEBUG
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700), // Emas
          secondary: Color(0xFF00E676), // Hijau
        ),
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield, size: 80, color: Colors.amber),
                const SizedBox(height: 20),
                const Text(
                  'AER FINANCIAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 50),

                // WIDGET CRYPTEX (PRODUCTION MODE)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: CryptexLock(
                    amount: 8000,
                    controller: ClaController(
                      const ClaConfig(
                        // RAHSIA 5 DIGIT (Tiada '0' sebab 0 ialah perangkap)
                        secret: [1, 7, 3, 9, 2], 
                        minSolveTime: Duration(seconds: 2),
                        minShake: 0.15, // Threshold Biometrik
                        jamCooldown: Duration(seconds: 60),
                        thresholdAmount: 5000,
                      ),
                    ),
                    // CALLBACKS (SILENT)
                    // Dalam production, jangan print log. Lakukan aksi terus.
                    onSuccess: () {
                      // TODO: Navigate to Transfer Success Page
                    },
                    onFail: () {
                      // TODO: Record failure count secretly
                    },
                    onJammed: () {
                      // TODO: Flag device ID as suspicious
                    },
                  ),
                ),
                
                const SizedBox(height: 50),
                const Text(
                  'SECURE ENCLAVE ACTIVE',
                  style: TextStyle(
                    color: Colors.white10, 
                    fontSize: 10,
                    letterSpacing: 2.0
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
