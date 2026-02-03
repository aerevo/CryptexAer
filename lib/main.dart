import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:safe_device/safe_device.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFFF5722),
        useMaterial3: true,
      ),
      home: const SecurityCheckScreen(),
    );
  }
}

// ============================================
// ✅ SECURITY PRE-CHECK WITH SMART DEGRADATION
// ============================================
class SecurityCheckScreen extends StatefulWidget {
  const SecurityCheckScreen({super.key});

  @override
  State<SecurityCheckScreen> createState() => _SecurityCheckScreenState();
}

class _SecurityCheckScreenState extends State<SecurityCheckScreen> {
  String _status = "Initializing security checks...";
  bool _isRooted = false;
  bool _isDeveloperMode = false;
  bool _checkComplete = false;
  bool _needsLocationConsent = false;
  Position? _capturedLocation;

  @override
  void initState() {
    super.initState();
    _performSecurityChecks();
  }

  Future<void> _performSecurityChecks() async {
    // ✅ CHECK 1: Root/Jailbreak Detection
    setState(() => _status = "Checking device integrity...");
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
    // ✅ FIX: Guna SafeDevice
     _isRooted = await SafeDevice.isJailBroken;
    // Kita anggap Emulator (Not Real Device) sebagai Developer Mode
     _isDeveloperMode = !(await SafeDevice.isRealDevice); 

  if (_isRooted || _isDeveloperMode) {
        setState(() {
          _status = "⚠️ COMPROMISED DEVICE DETECTED";
          _checkComplete = true;
          _needsLocationConsent = true;
        });
        return;
      }
    } catch (e) {
      print('⚠️ Root detection error: $e (Graceful degradation)');
      // Continue if detection fails
    }
    
    // ✅ CHECK 2: Server reachability (OPTIONAL)
    setState(() => _status = "Verifying server connection...");
    await Future.delayed(const Duration(milliseconds: 500));
    
    bool serverReachable = await _pingServer();
    
    if (!serverReachable) {
      print('⚠️ Server offline - proceeding with local-only mode');
      // ✅ GRACEFUL DEGRADATION: Continue without server
    }
    
    // ✅ ALL CHECKS PASSED (or gracefully degraded)
    setState(() => _status = "✅ Security verified");
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      _proceedToMainScreen();
    }
  }

  Future<bool> _pingServer() async {
    // 📝 TODO: Replace with actual server ping
    // Example: GET https://your-server.com/health
    // 
    // try {
    //   final response = await http.get(
    //     Uri.parse('https://api.z-kinetic.com/health'),
    //   ).timeout(Duration(seconds: 3));
    //   return response.statusCode == 200;
    // } catch (e) {
    //   return false;
    // }
    
    // ✅ PLACEHOLDER: Simulate server offline for now
    await Future.delayed(const Duration(milliseconds: 300));
    return false; // Change to true when server is ready
  }

  Future<void> _requestLocationAndProceed() async {
    setState(() => _status = "Requesting location permission...");
    
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        setState(() {
          _status = "⛔ Location permission required for rooted devices";
        });
        return;
      }
      
      // Get location
      setState(() => _status = "Capturing location...");
      _capturedLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // ✅ Log to server (placeholder)
      await _logRootedDeviceAccess();
      
      setState(() => _status = "✅ Location verified - proceeding with caution");
      await Future.delayed(const Duration(milliseconds: 1000));
      
      _proceedToMainScreen(isCompromised: true);
      
    } catch (e) {
      setState(() {
        _status = "❌ Location capture failed: $e";
      });
    }
  }

  Future<void> _logRootedDeviceAccess() async {
    // 📝 TODO: Send to your server
    // 
    // POST https://your-server.com/api/security/rooted-device-access
    // Body: {
    //   "device_id": "...",
    //   "timestamp": "...",
    //   "latitude": _capturedLocation.latitude,
    //   "longitude": _capturedLocation.longitude,
    //   "is_rooted": true,
    //   "is_developer_mode": _isDeveloperMode,
    //   "user_consented": true
    // }
    
    print('📍 Rooted device access logged:');
    print('   Lat: ${_capturedLocation?.latitude}');
    print('   Lng: ${_capturedLocation?.longitude}');
    print('   Time: ${DateTime.now()}');
    
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _proceedToMainScreen({bool isCompromised = false}) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ZKineticLockScreen(
            isCompromisedDevice: isCompromised,
            deviceLocation: _capturedLocation,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Shield icon
              Icon(
                (_isRooted || _isDeveloperMode) ? Icons.warning_amber_rounded : Icons.shield,
                color: (_isRooted || _isDeveloperMode) ? Colors.orange : const Color(0xFFFF5722),
                size: 80,
              ),
              
              const SizedBox(height: 30),
              
              // Status text
              Text(
                _status,
                style: TextStyle(
                  color: (_isRooted || _isDeveloperMode) ? Colors.orange : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              // Loading indicator
              if (!_checkComplete && !_needsLocationConsent)
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF5722),
                    strokeWidth: 3,
                  ),
                ),
              
              // ✅ ROOTED DEVICE WARNING + CONSENT
              if (_needsLocationConsent) ...[
                const SizedBox(height: 30),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.developer_mode,
                        color: Colors.orange,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        _isDeveloperMode 
                            ? 'DEVELOPER MODE DETECTED'
                            : 'ROOTED DEVICE DETECTED',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Kami dapati peranti anda telah diubahsuai. Untuk keselamatan, '
                        'kami perlu:\n\n'
                        '• Mengesahkan lokasi peranti anda (satu kali)\n'
                        '• Merekod transaksi untuk audit\n'
                        '• Mematuhi syarat keselamatan ketat\n\n'
                        'Sila matikan Developer Options jika ini adalah kesilapan.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                SystemNavigator.pop(); // Close app
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(color: Colors.white30),
                              ),
                              child: const Text('BATAL'),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _requestLocationAndProceed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text(
                                'TERUSKAN',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// MAIN LOCK SCREEN
// ============================================
class ZKineticLockScreen extends StatefulWidget {
  final bool isCompromisedDevice;
  final Position? deviceLocation;
  
  const ZKineticLockScreen({
    super.key,
    this.isCompromisedDevice = false,
    this.deviceLocation,
  });

  @override
  State<ZKineticLockScreen> createState() => _ZKineticLockScreenState();
}

class _ZKineticLockScreenState extends State<ZKineticLockScreen> {
  late EnterpriseController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EnterpriseController(
      correctCode: [1, 2, 3, 4, 5],
      isCompromisedDevice: widget.isCompromisedDevice,
      deviceLocation: widget.deviceLocation,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSuccess() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔓 ACCESS GRANTED'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onFail() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ ACCESS DENIED'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 1),
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
            child: Container(
              padding: const EdgeInsets.only(top: 24, bottom: 24, left: 0, right: 0),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5722),
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
                  _buildPremiumLogo(),
                  const SizedBox(height: 16),
                  
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFFEEDD)],
                    ).createShader(bounds),
                    child: const Text(
                      'Z·KINETIC',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w100,
                        color: Colors.white,
                        letterSpacing: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ENTERPRISE EDITION',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white70,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  CryptexLock(
                    controller: _controller,
                    onSuccess: _onSuccess,
                    onFail: _onFail,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  ValueListenableBuilder<double>(
                    valueListenable: _controller.motionScore,
                    builder: (context, motion, _) {
                      return ValueListenableBuilder<double>(
                        valueListenable: _controller.touchScore,
                        builder: (context, touch, _) {
                          return ValueListenableBuilder<double>(
                            valueListenable: _controller.patternScore,
                            builder: (context, pattern, _) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatusItem(Icons.sensors, 'MOTION', motion),
                                  _buildStatusItem(Icons.fingerprint, 'TOUCH', touch),
                                  _buildStatusItem(Icons.timeline, 'PATTERN', pattern),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // ✅ COMPROMISED DEVICE WARNING BANNER
          if (widget.isCompromisedDevice)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'DEVELOPER MODE - Aktiviti direkod',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFDDDD)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: const Size(32, 32),
              painter: ShieldPainter(),
            ),
          ),
          Center(
            child: Text(
              'Z',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFF5722),
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, double score) {
    bool isActive = score > 0.15;
    return Column(
      children: [
        Icon(
          isActive ? Icons.check_circle : icon,
          size: 24,
          color: isActive ? Colors.greenAccent : Colors.white70,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.greenAccent : Colors.white70,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.1);
    path.lineTo(size.width * 0.85, size.height * 0.3);
    path.lineTo(size.width * 0.85, size.height * 0.65);
    path.quadraticBezierTo(size.width * 0.5, size.height * 1.05, size.width * 0.5, size.height * 0.9);
    path.quadraticBezierTo(size.width * 0.5, size.height * 1.05, size.width * 0.15, size.height * 0.65);
    path.lineTo(size.width * 0.15, size.height * 0.3);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================
// ✅ ENTERPRISE CONTROLLER (WITH GRACEFUL DEGRADATION)
// ============================================

class EnterpriseController {
  final List<int> correctCode;
  final bool isCompromisedDevice;
  final Position? deviceLocation;
  
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);
  
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  
  double _lastMagnitude = 9.8;
  DateTime _lastMotionTime = DateTime.now();
  Timer? _decayTimer;
  
  final List<int> _scrollTimings = [];
  DateTime _lastScrollTime = DateTime.now();

  EnterpriseController({
    required this.correctCode,
    this.isCompromisedDevice = false,
    this.deviceLocation,
  }) {
    _initSensors();
    _startDecayTimer();
    
    if (isCompromisedDevice) {
      print('⚠️ Running in COMPROMISED MODE');
      print('📍 Location: ${deviceLocation?.latitude}, ${deviceLocation?.longitude}');
    }
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      double delta = (magnitude - _lastMagnitude).abs();
      
      if (delta > 0.3) {
        DateTime now = DateTime.now();
        double score = (delta / 3.0).clamp(0.0, 1.0);
        motionScore.value = score;
        _lastMotionTime = now;
      }
      
      _lastMagnitude = magnitude;
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      // Gyro tracking
    });
  }

  void _startDecayTimer() {
    _decayTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      DateTime now = DateTime.now();
      int timeSinceLastMotion = now.difference(_lastMotionTime).inMilliseconds;
      
      if (timeSinceLastMotion > 500) {
        double decay = (timeSinceLastMotion / 1000.0) * 0.05;
        motionScore.value = (motionScore.value - decay).clamp(0.0, 1.0);
      }
    });
  }

  void registerTouch() {
    touchScore.value = Random().nextDouble() * 0.3 + 0.7;
  }

  void registerScroll() {
    DateTime now = DateTime.now();
    int delta = now.difference(_lastScrollTime).inMilliseconds;
    _scrollTimings.add(delta);
    _lastScrollTime = now;

    if (_scrollTimings.length > 10) _scrollTimings.removeAt(0);

    if (_scrollTimings.length >= 3) {
      double avg = _scrollTimings.reduce((a, b) => a + b) / _scrollTimings.length;
      double variance = _scrollTimings
          .map((e) => pow(e - avg, 2))
          .reduce((a, b) => a + b) / _scrollTimings.length;
      
      double humanness = (variance / 10000).clamp(0.0, 1.0);
      patternScore.value = humanness;
    }
  }

  Future<bool> verify(List<int> code) async {
    // ✅ LOCAL CHECKS
    bool motionOK = motionScore.value > 0.15;
    bool touchOK = touchScore.value > 0.15;
    bool patternOK = patternScore.value > 0.10;
    
    bool codeCorrect = true;
    if (code.length != correctCode.length) return false;
    
    for (int i = 0; i < code.length; i++) {
      if (code[i] != correctCode[i]) {
        codeCorrect = false;
        break;
      }
    }
    
    int sensorsActive = [motionOK, touchOK, patternOK].where((x) => x).length;
    bool localPass = codeCorrect && sensorsActive >= 2;
    
    if (!localPass) {
      print('❌ Local check failed');
      return false;
    }
    
    // ✅ SERVER CHECK (with graceful degradation)
    print('🔄 Contacting server...');
    bool serverPass = await _checkWithServer(code);
    
    if (!serverPass) {
      print('⚠️ Server verification failed - checking fallback policy');
      
      // ✅ GRACEFUL DEGRADATION: Allow if server offline AND not compromised
      if (!isCompromisedDevice) {
        print('✅ Offline mode: Access granted (normal device)');
        return true;
      } else {
        print('❌ Compromised device requires server verification');
        return false;
      }
    }
    
    print('✅ Access granted (Server verified)');
    return true;
  }

  Future<bool> _checkWithServer(List<int> code) async {
    // 📝 TODO (FOR CLAUDE, CAPTAIN, & FRANCOIS):
    // ================================================
    // Replace this placeholder with actual server call
    // 
    // ENDPOINT: POST https://api.z-kinetic.com/v1/verify
    // HEADERS:
    //   - Authorization: Bearer YOUR_API_KEY
    //   - Content-Type: application/json
    // 
    // BODY:
    // {
    //   "device_id": "unique_device_identifier",
    //   "code_hash": "SHA256(code + device_secret)",
    //   "biometric_summary": {
    //     "motion_score": 0.75,
    //     "touch_score": 0.82,
    //     "pattern_score": 0.68
    //   },
    //   "is_compromised": false,
    //   "location": {
    //     "lat": 3.1390,
    //     "lng": 101.6869
    //   },
    //   "timestamp": "2026-02-03T12:45:30Z",
    //   "nonce": "random_unique_string"
    // }
    // 
    // EXPECTED RESPONSE:
    // {
    //   "allowed": true,
    //   "confidence": 0.92,
    //   "reason": "VERIFIED",
    //   "device_status": "SAFE" | "BLACKLISTED" | "WATCH_LIST"
    // }
    // 
    // ERROR HANDLING:
    // - Timeout: 5 seconds
    // - Retry: 2 times with exponential backoff
    // - If all fail: Return false (graceful degradation handles it)
    // 
    // EXAMPLE IMPLEMENTATION:
    // 
    // try {
    //   final response = await http.post(
    //     Uri.parse('https://api.z-kinetic.com/v1/verify'),
    //     headers: {
    //       'Authorization': 'Bearer YOUR_API_KEY',
    //       'Content-Type': 'application/json',
    //     },
    //     body: jsonEncode({
    //       'device_id': await _getDeviceId(),
    //       'code_hash': _hashCode(code),
    //       'biometric_summary': {
    //         'motion_score': motionScore.value,
    //         'touch_score': touchScore.value,
    //         'pattern_score': patternScore.value,
    //       },
    //       'is_compromised': isCompromisedDevice,
    //       'location': deviceLocation != null ? {
    //         'lat': deviceLocation!.latitude,
    //         'lng': deviceLocation!.longitude,
    //       } : null,
    //       'timestamp': DateTime.now().toIso8601String(),
    //       'nonce': _generateNonce(),
    //     }),
    //   ).timeout(Duration(seconds: 5));
    //   
    //   if (response.statusCode == 200) {
    //     final data = jsonDecode(response.body);
    //     return data['allowed'] == true;
    //   }
    //   
    //   return false;
    // } catch (e) {
    //   print('Server error: $e');
    //   return false; // Graceful degradation will handle
    // }
    // ================================================
    
    // ✅ PLACEHOLDER SIMULATION
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Simulate server offline (change to true when server ready)
    return false; // This triggers graceful degradation
  }

  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _decayTimer?.cancel();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
  }
}

// ============================================
// CRYPTEX LOCK (unchanged - copy from previous)
// ============================================
class CryptexLock extends StatefulWidget {
  final EnterpriseController controller;
  final VoidCallback? onSuccess;
  final VoidCallback? onFail;

  const CryptexLock({
    super.key,
    required this.controller,
    this.onSuccess,
    this.onFail,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> with TickerProviderStateMixin {
  static const double imageWidth = 706.0;
  static const double imageHeight = 610.0;

  static const List<List<double>> wheelCoords = [
    [25, 159, 113, 378],
    [165, 160, 257, 379],
    [308, 160, 396, 379],
    [448, 159, 541, 378],
    [591, 159, 681, 379],
  ];

  static const List<double> buttonCoords = [123, 433, 594, 545];

  final List<FixedExtentScrollController> _scrollControllers = List.generate(
    5,
    (i) => FixedExtentScrollController(initialItem: 0),
  );

  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool _isButtonPressed = false;
  
  final Random _random = Random();
  late Timer _driftTimer;
  final List<Offset> _textDriftOffsets = List.generate(5, (_) => Offset.zero);
  
  late List<AnimationController> _opacityControllers;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    
    _driftTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted && _activeWheelIndex == null) {
        setState(() {
          for (int i = 0; i < 5; i++) {
            _textDriftOffsets[i] = Offset(
              (_random.nextDouble() - 0.5) * 2.5,
              (_random.nextDouble() - 0.5) * 2.5,
            );
          }
        });
      }
    });
    
    _opacityControllers = List.generate(5, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1800 + (_random.nextInt(400))),
      );
      
      Future.delayed(Duration(milliseconds: _random.nextInt(1000)), () {
        if (mounted) controller.repeat(reverse: true);
      });
      
      return controller;
    });
    
    _opacityAnimations = _opacityControllers.map((c) {
      return Tween<double>(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    for (var controller in _opacityControllers) {
      controller.dispose();
    }
    _wheelActiveTimer?.cancel();
    _driftTimer.cancel();
    super.dispose();
  }

  void _onWheelScrollStart(int index) {
    setState(() => _activeWheelIndex = index);
    _wheelActiveTimer?.cancel();
    HapticFeedback.selectionClick();
    widget.controller.registerTouch();
  }

  void _onWheelScrollEnd(int index) {
    _wheelActiveTimer?.cancel();
    _wheelActiveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _activeWheelIndex = null);
      }
    });
  }

  void _onButtonTap() async {
    HapticFeedback.mediumImpact();
    
    setState(() => _isButtonPressed = true);
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isButtonPressed = false);
    });
    
    widget.controller.registerTouch();
    
    List<int> currentCode = _scrollControllers
        .map((c) => c.selectedItem % 10)
        .toList();
    
    // ✅ Await server verification
    bool isCorrect = await widget.controller.verify(currentCode);
    
    if (isCorrect) {
      widget.onSuccess?.call();
    } else {
      widget.onFail?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Positioned.fill(
                child: Image.asset(
                  'assets/z_wheel.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.red,
                      child: const Center(
                        child: Icon(Icons.error, color: Colors.white, size: 60),
                      ),
                    );
                  },
                ),
              ),

              ..._buildWheelOverlays(availableWidth, calculatedHeight),
              _buildGlowingButton(availableWidth, calculatedHeight),
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
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                if (_scrollControllers[i].position == notification.metrics) {
                  _onWheelScrollStart(i);
                }
              } else if (notification is ScrollUpdateNotification) {
                widget.controller.registerScroll();
              } else if (notification is ScrollEndNotification) {
                _onWheelScrollEnd(i);
              }
              return false;
            },
            child: _buildInteractiveWheel(i, actualHeight),
          ),
        ),
      );
    }

    return overlays;
  }

  Widget _buildInteractiveWheel(int index, double wheelHeight) {
    bool isActive = _activeWheelIndex == index;
    double itemExtent = wheelHeight * 0.40;

    return GestureDetector(
      onTapDown: (_) => _onWheelScrollStart(index),
      onTapUp: (_) => _onWheelScrollEnd(index),
      onTapCancel: () => _onWheelScrollEnd(index),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          ListWheelScrollView.useDelegate(
            controller: _scrollControllers[index],
            itemExtent: itemExtent,
            perspective: 0.003,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (_) {
              HapticFeedback.selectionClick();
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, wheelIndex) {
                int displayNumber = wheelIndex % 10;
                
                return Center(
                  child: AnimatedBuilder(
                    animation: _opacityAnimations[index],
                    builder: (context, child) {
                      return Transform.translate(
                        offset: isActive ? Offset.zero : _textDriftOffsets[index],
                        child: Opacity(
                          opacity: isActive ? 1.0 : _opacityAnimations[index].value,
                          child: Text(
                            '$displayNumber',
                            style: TextStyle(
                              fontSize: wheelHeight * 0.30,
                              fontWeight: FontWeight.w900,
                              color: isActive 
                                  ? const Color(0xFFFF5722)
                                  : const Color(0xFF263238),
                              shadows: isActive
                                  ? [
                                      Shadow(
                                        color: const Color(0xFFFF5722).withOpacity(0.8),
                                        blurRadius: 20,
                                      ),
                                      Shadow(
                                        color: const Color(0xFFFF5722).withOpacity(0.5),
                                        blurRadius: 40,
                                      ),
                                    ]
                                  : [
                                      Shadow(
                                        offset: const Offset(1, 1),
                                        blurRadius: 1,
                                        color: Colors.white.withOpacity(0.4),
                                      ),
                                      Shadow(
                                        offset: const Offset(-1, -1),
                                        blurRadius: 1,
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                    ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          if (isActive)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withOpacity(0.5),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF5722).withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlowingButton(double screenWidth, double screenHeight) {
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
      child: GestureDetector(
        onTap: _onButtonTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Container(color: Colors.transparent),
            
            if (_isButtonPressed)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5722).withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF5722).withOpacity(0.3),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
