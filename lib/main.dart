import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cryptex_lock/cryptex_lock.dart'; // Pintu masuk library

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // KUNCI ORIENTASI: Portrait Sahaja (Bank Grade)
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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
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

                // WIDGET BLACKBOX
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: CryptexLock(
                    amount: 8000,
                    controller: ClaController(
                      const ClaConfig(
                        // RAHSIA 5 DIGIT
                        secret: [1, 7, 3, 9, 2], 
                        minSolveTime: Duration(seconds: 2),
                        minShake: 0.15,
                        jamCooldown: Duration(seconds: 60),
                        thresholdAmount: 5000,
                      ),
                    ),
                    // CALLBACKS
                    onSuccess: () {
                      // Navigate to success
                    },
                    onFail: () {
                      // Log failure
                    },
                    onJammed: () {
                      // Log threat
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
