import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk kawalan orientasi
import 'cryptex_lock/cryptex_lock.dart';

void main() {
  // Pastikan orientasi kekal Portrait (Bank Grade standard)
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
      debugShowCheckedModeBanner: false, // Hilangkan banner DEBUG
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_moon, size: 80, color: Colors.amber),
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
                        secret: [1, 7, 3, 9, 2], 
                        minSolveTime: Duration(seconds: 2),
                        minShake: 0.15,
                        jamCooldown: Duration(seconds: 60),
                        thresholdAmount: 5000,
                      ),
                    ),
                    // CALLBACKS KOSONG (SILENT)
                    // Dalam production, ini akan navigasi ke page lain.
                    // Jangan print log rahsia di console.
                    onSuccess: () {
                      // Logic pindah screen diletakkan di sini nanti
                    },
                    onFail: () {
                      // Logic rekod cubaan gagal ke server (bukan print)
                    },
                    onJammed: () {
                      // Logic hantar amaran ke HQ
                    },
                  ),
                ),
                
                const SizedBox(height: 50),
                // Footer No Version untuk keselamatan (Security by Obscurity)
                const Text(
                  'SECURE ENCLAVE ACTIVE',
                  style: TextStyle(
                    color: Colors.white10, 
                    fontSize: 8,
                    letterSpacing: 1.0
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
