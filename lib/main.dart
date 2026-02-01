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
          padding: const EdgeInsets.only(
            top: 24,    // ✅ Padding atas bawah je
            bottom: 24,
            left: 0,    // ✅ KIRI 0
            right: 0,   // ✅ KANAN 0
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.security,
                color: Color(0xFFFF6F00),
                size: 48,
              ),
              const SizedBox(height: 12),
              
              const Text(
                'Z-KINETIC',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF6F00),
                  letterSpacing: 3,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // ✅ GAMBAR TANPA BORDER RADIUS, FULL WIDTH
              Image.asset(
                'assets/z_wheel.png',
                width: double.infinity,  // ✅ FULL WIDTH
                fit: BoxFit.cover,       // ✅ COVER PENUH
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.red,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error, color: Colors.white, size: 60),
                          SizedBox(height: 10),
                          Text(
                            'IMAGE ERROR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusItem(Icons.sensors, 'MOTION'),
                  _buildStatusItem(Icons.fingerprint, 'TOUCH'),
                  _buildStatusItem(Icons.timeline, 'PATTERN'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
