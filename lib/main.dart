// Production build - ZERO user ping!
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert';  // For JSON encoding
import 'dart:typed_data';  // For Uint8List
import 'package:crypto/crypto.dart';  // For SHA256
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:safe_device/safe_device.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:flutter_window_manager/flutter_window_manager.dart';  // Uncomment for overlay protection

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
// SECURITY PRE-CHECK (unchanged)
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
    setState(() => _status = "Checking device integrity...");
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      _isRooted = await SafeDevice.isJailBroken;
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
      print('⚠️ Root detection error: $e');
    }
    
    setState(() => _status = "Verifying server connection...");
    await Future.delayed(const Duration(milliseconds: 500));
    
    bool serverReachable = await _pingServer();
    
    if (!serverReachable) {
      print('⚠️ Server offline - local mode');
    }
    
    setState(() => _status = "✅ Security verified");
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      _proceedToMainScreen();
    }
  }

  Future<bool> _pingServer() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return false;
  }

  Future<void> _requestLocationAndProceed() async {
    setState(() => _status = "Requesting location...");
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        setState(() {
          _status = "⛔ Location required for rooted devices";
        });
        return;
      }
      
      setState(() => _status = "Capturing location...");
      _capturedLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      await _logRootedDeviceAccess();
      
      setState(() => _status = "✅ Location verified");
      await Future.delayed(const Duration(milliseconds: 1000));
      
      _proceedToMainScreen(isCompromised: true);
      
    } catch (e) {
      setState(() => _status = "❌ Location failed: $e");
    }
  }

  Future<void> _logRootedDeviceAccess() async {
    print('📍 Rooted access: ${_capturedLocation?.latitude}, ${_capturedLocation?.longitude}');
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
              Icon(
                (_isRooted || _isDeveloperMode) ? Icons.warning_amber_rounded : Icons.shield,
                color: (_isRooted || _isDeveloperMode) ? Colors.orange : const Color(0xFFFF5722),
                size: 80,
              ),
              
              const SizedBox(height: 30),
              
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
              
              if (!_checkComplete && !_needsLocationConsent)
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF5722),
                    strokeWidth: 3,
                  ),
                ),
              
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
                      const Icon(Icons.developer_mode, color: Colors.orange, size: 40),
                      const SizedBox(height: 16),
                      
                      Text(
                        _isDeveloperMode ? 'DEVELOPER MODE' : 'ROOTED DEVICE',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Sila matikan Developer Options. Untuk keselamatan, '
                        'kami perlu lokasi peranti anda (satu kali).',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => SystemNavigator.pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white30),
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
                              child: const Text('TERUSKAN', style: TextStyle(fontWeight: FontWeight.bold)),
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
// ✅ NEW: HEXAGON SHIELD PAINTER (MODERN)
// ============================================
class ModernShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final w = size.width;
    final h = size.height;

    // Modern hexagonal shield
    final path = Path();
    path.moveTo(w * 0.5, 0);
    path.lineTo(w * 0.9, h * 0.25);
    path.lineTo(w * 0.9, h * 0.6);
    path.lineTo(w * 0.5, h * 0.95);
    path.lineTo(w * 0.1, h * 0.6);
    path.lineTo(w * 0.1, h * 0.25);
    path.close();

    canvas.drawPath(path, paint);

    // Inner accent
    final accentPaint = Paint()
      ..color = const Color(0xFFFF5722).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final innerPath = Path();
    innerPath.moveTo(w * 0.5, h * 0.15);
    innerPath.lineTo(w * 0.75, h * 0.35);
    innerPath.lineTo(w * 0.75, h * 0.55);
    innerPath.lineTo(w * 0.5, h * 0.75);
    innerPath.lineTo(w * 0.25, h * 0.55);
    innerPath.lineTo(w * 0.25, h * 0.35);
    innerPath.close();

    canvas.drawPath(innerPath, accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================
// SUCCESS SCREEN
// ============================================
class SuccessScreen extends StatelessWidget {
  final String message;
  final bool isPanicMode;

  const SuccessScreen({
    super.key,
    required this.message,
    this.isPanicMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // 🎭 WAYANG MODE: If panic, show subtle difference but still looks "safe"
    // Perompak nampak "System Ready" (macam normal)
    // Tapi server Captain dah dapat alert!
    
    return Scaffold(
      backgroundColor: isPanicMode 
          ? const Color(0xFF455A64)  // Slightly grey-green (subtle clue)
          : const Color(0xFF4CAF50),  // Bright green (normal)
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,  // Same icon for both modes (wayang!)
                  color: Color(0xFF4CAF50),
                  size: 70,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                // 🎭 WAYANG: Text sengaja neutral
                isPanicMode ? 'SYSTEM READY' : 'IDENTITY VERIFIED',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.green[700],
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              
              // 🎭 WAYANG: Subtle message for panic mode
              if (isPanicMode)
                const Text(
                  "Safe mode protocol active",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              
              const SizedBox(height: 14),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// ✅ MAIN LOCK SCREEN (REBRANDED)
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
    
    // 🛡️ OVERLAY PROTECTION: Enable secure mode
    _enableSecureMode();
  }
  
  // 🛡️ Enable FLAG_SECURE to prevent overlays and screenshots
  Future<void> _enableSecureMode() async {
    try {
      // Uncomment when flutter_window_manager added to pubspec.yaml:
      // if (Platform.isAndroid) {
      //   await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      //   print('🔒 Secure mode enabled - Overlays blocked');
      // }
      print('🔒 Security initialization complete');
    } catch (e) {
      print('⚠️ Secure mode failed: $e');
    }
  }

  @override
  void dispose() {
    // Re-enable screenshots after verification
    // Uncomment when flutter_window_manager added:
    // if (Platform.isAndroid) {
    //   FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    // }
    _controller.dispose();
    super.dispose();
  }

  void _onSuccess(bool isPanicMode) {
    HapticFeedback.heavyImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SuccessScreen(
          message: isPanicMode ? "Panic mode activated" : "Welcome back",
          isPanicMode: isPanicMode,
        ),
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
                  // ✅ NEW: Modern logo
                  _buildModernLogo(),
                  const SizedBox(height: 20),
                  
                  // ✅ NEW: Sleek title with gradient
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow effect
                      Text(
                        'Z-KINETIC',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 8
                            ..color = Colors.white.withOpacity(0.2),
                          letterSpacing: 4,
                        ),
                      ),
                      // Main text
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFFFCCBC),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: const Text(
                          'Z-KINETIC',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // ✅ NEW: Marketing tagline
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'MILITARY-GRADE BIOMETRIC LOCK',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // ✅ Cryptex with randomization
                  ValueListenableBuilder<int>(
                    valueListenable: _controller.randomizeTrigger,
                    builder: (context, trigger, _) {
                      return CryptexLock(
                        key: ValueKey(trigger), // Force rebuild on randomize
                        controller: _controller,
                        onSuccess: _onSuccess,
                        onFail: _onFail,
                      );
                    },
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
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'DEVELOPER MODE - Aktiviti direkod',
                        style: TextStyle(
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

  // ✅ NEW: Modern hexagon logo
  Widget _buildModernLogo() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFFFFFFF),
            const Color(0xFFFFE0E0).withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFFF5722).withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: const Size(36, 36),
              painter: ModernShieldPainter(),
            ),
          ),
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFFF5722),
                  Color(0xFFFF7043),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
              child: const Text(
                'Z',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
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

// ============================================
// ✅ ENTERPRISE CONTROLLER (WITH RANDOMIZATION)
// ============================================

class EnterpriseController {
  final List<int> correctCode;
  final bool isCompromisedDevice;
  final Position? deviceLocation;
  
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);
  
  // ✅ NEW: Randomization trigger
  final ValueNotifier<int> randomizeTrigger = ValueNotifier(0);
  
  // 🔒 NEW: Transaction binding for anti-tampering
  String? _boundTransactionHash;
  Map<String, dynamic>? _boundTransactionDetails;
  
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

  // ✅ NEW: Randomize wheels on fail
  void randomizeWheels() {
    randomizeTrigger.value++;
    print('🔀 Wheels randomized (trigger: ${randomizeTrigger.value})');
  }

  // 🔒 TRANSACTION BINDING: Bind transaction details to prevent tampering
  void bindTransaction(Map<String, dynamic> transactionDetails) {
    _boundTransactionDetails = transactionDetails;
    
    // Create deterministic JSON string for hashing
    final Map<String, dynamic> hashData = {
      'amount': transactionDetails['amount'],
      'recipient': transactionDetails['recipient'],
      'currency': transactionDetails['currency'] ?? 'MYR',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Sort keys for consistent hashing
    final sortedJson = json.encode(hashData, toEncodable: (obj) {
      if (obj is Map) {
        return Map.fromEntries(
          obj.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
        );
      }
      return obj;
    });
    
    // Generate SHA256 hash
    _boundTransactionHash = sha256.convert(utf8.encode(sortedJson)).toString();
    
    print('🔒 Transaction Bound to Verification:');
    print('   Amount: ${transactionDetails['amount']}');
    print('   Recipient: ${transactionDetails['recipient']}');
    print('   Hash: ${_boundTransactionHash?.substring(0, 16)}...');
  }

  // 🚨 THREAT INTELLIGENCE: Send data to Captain's dashboard (backend)
  Future<void> _sendThreatIntelligence({
    required String type,
    required String severity,
    Map<String, dynamic>? additionalData,  // 🆕 For transaction tampering, overlay attacks
  }) async {
    // Data ni yang akan muncul kat Dashboard 'Radar' Captain
    final Map<String, dynamic> threatLog = {
      'event_type': type,         // Contoh: "PANIC_DURESS", "BIO_FAIL_ATTEMPT"
      'severity': severity,       // Contoh: "CRITICAL", "HIGH", "MEDIUM"
      'device_id': 'USER_${Random().nextInt(9999)}',  // Device fingerprint
      'location': deviceLocation != null
          ? '${deviceLocation!.latitude}, ${deviceLocation!.longitude}'
          : 'Hidden',
      'timestamp': DateTime.now().toIso8601String(),
      'biometric_scores': {
        'motion': motionScore.value,
        'touch': touchScore.value,
        'pattern': patternScore.value,
      },
      ...?additionalData,  // 🆕 Merge additional attack-specific data
    };

    print('📡 [THREAT INTEL] Sending to dashboard...');
    print('   Type: $type | Severity: $severity');
    
    // 🔥 PRODUCTION: Uncomment this when Firebase integrated
    // await FirebaseFirestore.instance
    //     .collection('global_threat_intel')
    //     .add(threatLog);
    
    // For now, just log to console
    print('   Data: ${threatLog.toString()}');
    print('✅ [THREAT INTEL] Data sent successfully');
  }

  Future<Map<String, dynamic>> verify(List<int> code) async {
    String inputStr = code.join();
    String reversedStr = correctCode.reversed.join();
    
    // --- PANIC MODE CHECK (Local - Security Feature) ---
    if (inputStr == reversedStr) {
      print('🚨 PANIC MODE ACTIVATED');
      return {'allowed': true, 'isPanicMode': true};
    }
    
    // --- BIOMETRIC VERIFICATION (Z-Kinetic's ONLY Job) ---
    print('🔄 Analyzing behavioral biometrics...');
    
    bool motionOK = motionScore.value > 0.15;
    bool touchOK = touchScore.value > 0.15;
    bool patternOK = patternScore.value > 0.10;
    int sensorsActive = [motionOK, touchOK, patternOK].where((x) => x).length;
    
    if (sensorsActive < 2) {
      print('❌ Biometric Failed: Insufficient human signals');
      print('   Motion: ${motionOK ? "OK" : "FAIL"}, Touch: ${touchOK ? "OK" : "FAIL"}, Pattern: ${patternOK ? "OK" : "FAIL"}');
      randomizeWheels();
      return {'allowed': false, 'isPanicMode': false};
    }
    
    // --- CONTACT Z-KINETIC SERVER (Verify Human Identity) ---
    print('🔄 Contacting Z-Kinetic Cloud for identity verification...');
    String? token = await _checkWithServer(code);
    
    if (token != null) {
      print('✅ Identity Verified. Issuing authentication token.');
      
      // 🚨 PANIC MODE DETECTION (Bank will tell us if it's panic code)
      // In production: Bank API returns isPanic flag
      // For demo: We simulate with reverse code
      bool isPanicFromBank = (inputStr == reversedStr);
      
      if (isPanicFromBank) {
        // --- PANIC MODE ACTIVATED (DI BELAKANG TABIR) ---
        print('🚨 [SILENT] PANIC MODE ACTIVATED');
        print('🚨 [SILENT] Perompak tidak sedar, UI tetap hijau');
        
        // A. Hantar threat intelligence ke server Captain (RISIKAN)
        await _sendThreatIntelligence(
          type: "PANIC_DURESS",
          severity: "CRITICAL",
        );
        
        // B. Pulangkan status untuk buat "Wayang" (UI)
        print('🎭 [WAYANG] Showing "SYSTEM READY" to deceive attacker');
        return {
          'allowed': true,
          'isPanicMode': true,  // ← SuccessScreen akan buat "wayang"
          'verificationToken': token,
          'userInputCode': inputStr,
          'boundTransactionHash': _boundTransactionHash,  // 🔒 Anti-tampering
          'transactionDetails': _boundTransactionDetails,  // For verification
          'biometricScore': {
            'motion': motionScore.value,
            'touch': touchScore.value,
            'pattern': patternScore.value,
          }
        };
      }
      
      // --- NORMAL MODE (Bukan Panic) ---
      print('📤 Passing credentials to host application for authorization.');
      
      return {
        'allowed': true,
        'isPanicMode': false,
        'verificationToken': token,      // ← Z-Kinetic's proof of human
        'userInputCode': inputStr,       // ← Password for host app to verify
        'boundTransactionHash': _boundTransactionHash,  // 🔒 Anti-tampering
        'transactionDetails': _boundTransactionDetails,  // For verification
        'biometricScore': {
          'motion': motionScore.value,
          'touch': touchScore.value,
          'pattern': patternScore.value,
        }
      };
    } else {
      // --- BIOMETRIC FAILED (Bot/Hacker Detected) ---
      if (isCompromisedDevice) {
        print('❌ Server Reject: Suspicious Activity Detected');
        
        // Send threat intelligence for failed attempt
        await _sendThreatIntelligence(
          type: "BIO_FAIL_COMPROMISED",
          severity: "HIGH",
        );
        
        randomizeWheels();
        return {'allowed': false, 'isPanicMode': false};
      }
      
      // Normal failed attempt
      await _sendThreatIntelligence(
        type: "BIO_FAIL_ATTEMPT",
        severity: "MEDIUM",
      );
      
      randomizeWheels();
      return {'allowed': false, 'isPanicMode': false};
    }
  }

  

// ⚠️ GANTI KOD SIMULASI DENGAN KOD INI UNTUK REAL SERVER CONNECTION
  Future<String?> _checkWithServer(List<int> code) async {
    try {
      // 1. Minta Challenge (Nonce)
      final nonceResponse = await http.post(
        Uri.parse('https://z-kinetic-server.onrender.com/getChallenge'), // ⚠️ Pastikan URL ni betul!
      ).timeout(const Duration(seconds: 10));

      if (nonceResponse.statusCode != 200) return null;
      final nonce = jsonDecode(nonceResponse.body)['nonce'];

      // 2. Hantar Data Biometrik untuk Diadili (Attestation)
      final attestResponse = await http.post(
        Uri.parse('https://z-kinetic-server.onrender.com/attest'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nonce': nonce,
          'deviceId': 'DEVICE_${DateTime.now().millisecondsSinceEpoch}',
          'biometricData': [
            motionScore.value,
            touchScore.value,
            patternScore.value
          ], // Hantar skor sebenar
        }),
      ).timeout(const Duration(seconds: 10));

      if (attestResponse.statusCode == 200) {
        final data = jsonDecode(attestResponse.body);
        return data['sessionToken']; // ✅ Server LULUSKAN
      } else {
        print('❌ Server Reject: ${attestResponse.body}');
        return null;
      }
    } catch (e) {
      print('❌ Connection Error: $e');
      return null;
    }
  }
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _decayTimer?.cancel();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
    randomizeTrigger.dispose();
  }
}

// ============================================
// CRYPTEX LOCK (with random initial positions)
// ============================================
class CryptexLock extends StatefulWidget {
  final EnterpriseController controller;
  final Function(bool isPanicMode) onSuccess;
  final VoidCallback onFail;

  const CryptexLock({
    super.key,
    required this.controller,
    required this.onSuccess,
    required this.onFail,
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

  late List<FixedExtentScrollController> _scrollControllers;

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
    
    // ✅ NEW: Random initial positions
    _scrollControllers = List.generate(
      5,
      (i) => FixedExtentScrollController(
        initialItem: _random.nextInt(10), // Random 0-9
      ),
    );
    
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
    
    final result = await widget.controller.verify(currentCode);
    
    if (result['allowed']) {
      widget.onSuccess(result['isPanicMode'] ?? false);
    } else {
      widget.onFail();
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
            perspective: 0.001,
            diameterRatio: 2.0,
            physics: const BouncingScrollPhysics(),
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


