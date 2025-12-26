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
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CryptexLock(
            amount: 8000, // contoh transaksi
            controller: ClaController(
              ClaConfig(
                secret: const [1, 7, 3, 9, 2, 8, 4, 6],
                minSolveTime: const Duration(seconds: 2),
                minShake: 0.15,
                jamCooldown: const Duration(seconds: 120),
                thresholdAmount: 5000,
              ),
            ),
            onSuccess: () => debugPrint('UNLOCK SUCCESS'),
            onFail: () => debugPrint('UNLOCK FAIL'),
            onJammed: () => debugPrint('SYSTEM JAMMED'),
          ),
        ),
      ),
    );
  }
}
