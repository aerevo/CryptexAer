import 'package:flutter/material.dart';
import 'dart:convert';
import 'cryptex_lock/cryptex_lock.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
              ClaConfig(
                secret: 'AER-CRY-001',
                minSolveTime: const Duration(seconds: 2),
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



