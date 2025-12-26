import 'package:flutter/material.dart';
import 'cryptex_lock/cryptex_lock.dart';

void main() {
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
          primary: Color(0xFFFFD700), // Emas
          secondary: Color(0xFF00E676), // Hijau Neon
        ),
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tajuk Demo
                const Icon(Icons.shield_moon, size: 80, color: Colors.amber),
                const SizedBox(height: 20),
                const Text(
                  'BANK OF AER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'High Value Transaction Approval',
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 50),

                // WIDGET CRYPTEX LOCK (INTEGRASI PENUH)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: CryptexLock(
                    amount: 8000, // Transaksi melebihi threshold
                    controller: ClaController(
                      const ClaConfig(
                        // PENTING: Mesti 5 digit sahaja untuk V2.0 (5-Wheel)
                        // PENTING: Jangan guna '0' dalam rahsia, '0' adalah perangkap!
                        secret: [1, 7, 3, 9, 2], 
                        
                        minSolveTime: Duration(seconds: 2), // Anti-Bot Timer
                        minShake: 0.20, // Sensitiviti gegaran (Dinaikkan sedikit)
                        jamCooldown: Duration(seconds: 60), // Tempoh denda
                        thresholdAmount: 5000, // Had aktif
                      ),
                    ),
                    onSuccess: () {
                      debugPrint('CRYPTEX: ACCESS GRANTED');
                      // Simulasi navigasi ke skrin berjaya
                    },
                    onFail: () {
                      debugPrint('CRYPTEX: WRONG COMBINATION');
                    },
                    onJammed: () {
                      debugPrint('CRYPTEX: BOT DETECTED - SYSTEM JAMMED');
                    },
                  ),
                ),
                
                const SizedBox(height: 50),
                const Text(
                  'SECURED BY CLA V2.0',
                  style: TextStyle(
                    color: Colors.white24, 
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
