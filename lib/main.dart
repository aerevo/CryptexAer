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

  // ✅ KOORDINAT BETUL (UPDATED)
  static const double imageWidth = 706.0;
  static const double imageHeight = 610.0;

  // 5 Roda coordinates [left, top, right, bottom]
  static const List<List<double>> wheelCoords = [
    [25, 159, 113, 378],   // Roda 1
    [165, 160, 257, 379],  // Roda 2
    [308, 160, 396, 379],  // Roda 3
    [448, 159, 541, 378],  // Roda 4
    [591, 159, 681, 379],  // Roda 5
  ];

  // Butang coordinates [left, top, right, bottom]
  static const List<double> buttonCoords = [123, 433, 594, 545];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          padding: const EdgeInsets.only(
            top: 24,
            bottom: 24,
            left: 0,
            right: 0,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            // ✅ OREN FUNKY BALIK!
            color: const Color(0xFFFF5722), // Material Deep Orange - VIBRANT!
            
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
                color: Colors.white, // ✅ PUTIH sebab background oren
                size: 48,
              ),
              const SizedBox(height: 12),
              
              const Text(
                'Z-KINETIC',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white, // ✅ PUTIH sebab background oren
                  letterSpacing: 3,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // ✅ GAMBAR + OVERLAY PENANDA
              _buildWheelSystem(),
              
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

  Widget _buildWheelSystem() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double aspectRatio = imageWidth / imageHeight;
        double calculatedHeight = availableWidth / aspectRatio;

        return SizedBox(
          width: availableWidth,
          height: calculatedHeight,
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Image.asset(
                  'assets/z_wheel.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
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
              ),
              
              // ✅ 5 WHEEL OVERLAYS
              ..._buildWheelOverlays(availableWidth, calculatedHeight),
              
              // ✅ BUTTON OVERLAY
              _buildButtonOverlay(availableWidth, calculatedHeight),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildWheelOverlays(double screenWidth, double screenHeight) {
    List<Widget> overlays = [];
    
    for (int i = 0; i < wheelCoords.length; i++) {
      double left = wheelCoords[i][0];
      double top = wheelCoords[i][1];
      double right = wheelCoords[i][2];
      double bottom = wheelCoords[i][3];
      
      double actualLeft = screenWidth * (left / imageWidth);
      double actualTop = screenHeight * (top / imageHeight);
      double actualWidth = screenWidth * ((right - left) / imageWidth);
      double actualHeight = screenHeight * ((bottom - top) / imageHeight);
      
      overlays.add(
        Positioned(
          left: actualLeft,
          top: actualTop,
          width: actualWidth,
          height: actualHeight,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
              color: Colors.red.withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                'W${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return overlays;
  }

  Widget _buildButtonOverlay(double screenWidth, double screenHeight) {
    double left = buttonCoords[0];
    double top = buttonCoords[1];
    double right = buttonCoords[2];
    double bottom = buttonCoords[3];
    
    double actualLeft = screenWidth * (left / imageWidth);
    double actualTop = screenHeight * (top / imageHeight);
    double actualWidth = screenWidth * ((right - left) / imageWidth);
    double actualHeight = screenHeight * ((bottom - top) / imageHeight);
    
    return Positioned(
      left: actualLeft,
      top: actualTop,
      width: actualWidth,
      height: actualHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 2),
          color: Colors.green.withOpacity(0.2),
        ),
        child: const Center(
          child: Text(
            'BUTTON',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
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
          color: Colors.white70, // ✅ PUTIH sebab background oren
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70, // ✅ PUTIH sebab background oren
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
