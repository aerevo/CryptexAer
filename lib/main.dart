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
            controller: ClaController(
              const ClaConfig(
                // ⛔ BUKAN STRING
                secret: [1, 7, 3, 9, 2, 8, 4, 6],
                minSolveTime: Duration(seconds: 2),
                minShake: 0.2,
              ),
            ),
            onSuccess: () {
              debugPrint('UNLOCK SUCCESS');
            },
            onFail: () {
              debugPrint('UNLOCK FAIL');
            },
            onJammed: () {
              debugPrint('SYSTEM JAMMED');
            },
          ),
        ),
      ),
    );
  }
}
