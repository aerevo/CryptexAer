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
                minSolveTime: Duration(seconds: 2),
                minShake: 0.2,
                thresholdAmount: 5000,
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
