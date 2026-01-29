import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import widget Pink kita
import 'cryptex_lock/src/cla_widget.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Kunci skrin menegak
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Z-Kinetic Test',
      theme: ThemeData.dark(), // Tema gelap
      
      // PANGGIL TERUS WIDGET PINK (ATAU GAMBAR)
      home: Scaffold(
        backgroundColor: Colors.black,
        body: const CryptexLock(), 
      ),
    );
  }
}
