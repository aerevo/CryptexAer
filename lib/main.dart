import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ImageTestScreen(),
    );
  }
}

class ImageTestScreen extends StatelessWidget {
  const ImageTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.orange, width: 5),
          ),
          child: Image.asset(
            'assets/z_wheel.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Kalau gambar tak jumpa, tunjuk error
              return Container(
                color: Colors.red,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error, color: Colors.white, size: 60),
                      SizedBox(height: 10),
                      Text(
                        'IMAGE ERROR',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
