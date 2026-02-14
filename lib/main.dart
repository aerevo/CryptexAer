import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC PRODUK B - FLUTTER CLIENT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Changes from Captain's original:
// 1. Removed SafeDevice & Geolocator (not needed for Produk B)
// 2. Removed SecurityCheckScreen (straight to widget)
// 3. Removed panic mode & dual-mode (3-wheel only for Produk B)
// 4. Updated server endpoints to /api/v1/challenge and /api/v1/verify
// 5. Kept all beautiful UI from Captain!
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFFF5722),
        useMaterial3: true,
      ),
      home: const ZKineticProdukBDemo(),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DEMO SCREEN (Example Integration)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticProdukBDemo extends StatefulWidget {
  const ZKineticProdukBDemo({super.key});

  @override
  State<ZKineticProdukBDemo> createState() => _ZKineticProdukBDemoState();
}

class _ZKineticProdukBDemoState extends State<ZKineticProdukBDemo> {
  bool _showWidget = false;
  late WidgetController _controller;

  @override
  void initState() {
    super.initState();
    // GANTI URL NI DENGAN SERVER CAPTAIN!
    _controller = WidgetController(
      serverUrl: 'http://192.168.1.5:3000';
      // serverUrl: 'https://your-server.onrender.com', // Production
    );
  }

  void _onPurchaseClick() {
    setState(() => _showWidget = true);
  }

  void _onVerificationComplete(bool success) {
    setState(() => _showWidget = false);
    
    if (success) {
      _showDialog('✅ Verified!', 'Human verified. Processing purchase...');
    } else {
      _showDialog('🚫 Bot Detected', 'Automated bot detected. Purchase blocked.');
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.confirmation_number, size: 80, color: Colors.orange),
                const SizedBox(height: 20),
                const Text(
                  'Concert Tickets',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'BTS World Tour 2026',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                const Text(
                  'RM 299',
                  style: TextStyle(fontSize: 48, color: Colors.green, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'per ticket',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _onPurchaseClick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'BUY TICKET',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Z-Kinetic Widget (GUNA UI CANTIK CAPTAIN!)
          if (_showWidget)
            ZKineticWidgetProdukB(
              controller: _controller,
              onComplete: _onVerificationComplete,
              onCancel: () => setState(() => _showWidget = false),
            ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// WIDGET CONTROLLER (Connect to Produk B Server)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WidgetController {
  final String serverUrl;
  
  String? _currentNonce;
  final ValueNotifier<List<int>> challengeCode = ValueNotifier([]);
  
  // Biometric tracking
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);
  
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _lastMagnitude = 9.8;
  
  WidgetController({required this.serverUrl}) {
    _initSensors();
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      double delta = (magnitude - _lastMagnitude).abs();
      if (delta > 0.3) {
        motionScore.value = (delta / 3.0).clamp(0.0, 1.0);
      }
      _lastMagnitude = magnitude;
    });
  }

  Future<bool> fetchChallenge() async {
    try {
      print('🔄 Fetching challenge from: $serverUrl/api/v1/challenge');
      
      final response = await http.post(
        Uri.parse('$serverUrl/api/v1/challenge'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          _currentNonce = data['nonce'];
          List<dynamic> rawCode = data['challengeCode'];
          challengeCode.value = rawCode.map((e) => e as int).toList();
          
          print('✅ Challenge received: ${challengeCode.value}');
          return true;
        }
      }
      
      print('❌ Server error: ${response.statusCode}');
      return false;
      
    } catch (e) {
      print('❌ Network error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> verify(List<int> userResponse) async {
    if (_currentNonce == null) {
      return {'allowed': false, 'error': 'No active challenge'};
    }
    
    try {
      print('🔄 Verifying response...');
      
      final response = await http.post(
        Uri.parse('$serverUrl/api/v1/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nonce': _currentNonce,
          'userResponse': userResponse,
          'biometricData': {
            'motion': motionScore.value,
            'touch': touchScore.value,
            'pattern': patternScore.value,
          },
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Server verdict: ${data['allowed']}');
        return data;
      }
      
      print('❌ Verification failed: ${response.statusCode}');
      return {'allowed': false, 'error': 'Server error'};
      
    } catch (e) {
      print('❌ Network error: $e');
      return {'allowed': false, 'error': 'Network error'};
    }
  }

  void registerTouch() => touchScore.value = Random().nextDouble() * 0.3 + 0.7;
  void registerScroll() => patternScore.value = 0.8;

  void dispose() {
    _accelSub?.cancel();
    challengeCode.dispose();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC WIDGET (GUNA UI CAPTAIN YANG CANTIK!)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticWidgetProdukB extends StatefulWidget {
  final WidgetController controller;
  final Function(bool success) onComplete;
  final VoidCallback onCancel;

  const ZKineticWidgetProdukB({
    super.key,
    required this.controller,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<ZKineticWidgetProdukB> createState() => _ZKineticWidgetProdukBState();
}

class _ZKineticWidgetProdukBState extends State<ZKineticWidgetProdukB> 
    with SingleTickerProviderStateMixin {
  
  bool _loading = true;
  String _status = 'Loading security check...';
  late AnimationController _glitchController;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..repeat(reverse: true);
    
    _initialize();
  }

  @override
  void dispose() {
    _glitchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final success = await widget.controller.fetchChallenge();
    
    if (success) {
      setState(() {
        _loading = false;
        _status = 'Verify you are human';
      });
    } else {
      setState(() {
        _loading = false;
        _status = 'Error loading challenge';
      });
    }
  }

  void _onVerify(List<int> userCode) async {
    setState(() {
      _loading = true;
      _status = 'Verifying...';
    });
    
    final result = await widget.controller.verify(userCode);
    
    widget.onComplete(result['allowed'] == true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5722),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'Z-KINETIC',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Subtitle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'BOT DETECTION',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Status
              Text(
                _status,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              
              const SizedBox(height: 20),
              
              // Loading or Widget
              if (_loading)
                const CircularProgressIndicator(color: Colors.white)
              else
                ZKineticCryptex3Wheel(
                  controller: widget.controller,
                  onSubmit: _onVerify,
                ),
              
              const SizedBox(height: 20),
              
              // Cancel button
              TextButton(
                onPressed: widget.onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 3-WHEEL CRYPTEX (CAPTAIN'S BEAUTIFUL UI!)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticCryptex3Wheel extends StatefulWidget {
  final WidgetController controller;
  final Function(List<int>) onSubmit;

  const ZKineticCryptex3Wheel({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  @override
  State<ZKineticCryptex3Wheel> createState() => _ZKineticCryptex3WheelState();
}

class _ZKineticCryptex3WheelState extends State<ZKineticCryptex3Wheel> {
  late List<FixedExtentScrollController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (_) => FixedExtentScrollController(initialItem: Random().nextInt(10)),
    );
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSubmit() {
    List<int> code = _controllers.map((c) => c.selectedItem % 10).toList();
    widget.onSubmit(code);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Challenge display (with glitch effect!)
        ValueListenableBuilder<List<int>>(
          valueListenable: widget.controller.challengeCode,
          builder: (context, code, _) {
            if (code.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.5),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: code.map((digit) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$digit',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                        fontFamily: 'Courier',
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        
        const SizedBox(height: 15),
        
        const Text(
          'Match the code above',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        
        const SizedBox(height: 15),
        
        // 3 wheels (CAPTAIN'S BEAUTIFUL DESIGN!)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 70,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white30, width: 2),
              ),
              child: ListWheelScrollView.useDelegate(
                controller: _controllers[i],
                itemExtent: 46,
                perspective: 0.003,
                diameterRatio: 1.5,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (_) {
                  HapticFeedback.selectionClick();
                  widget.controller.registerScroll();
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, index) {
                    int digit = index % 10;
                    return Center(
                      child: Text(
                        '$digit',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }),
        ),
        
        const SizedBox(height: 20),
        
        // Verify button
        ElevatedButton(
          onPressed: _onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            'VERIFY',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}

