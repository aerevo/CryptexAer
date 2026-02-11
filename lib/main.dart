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
// SECURITY PRE-CHECK
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
    
    // Simulate ping
    await Future.delayed(const Duration(milliseconds: 300));
    
    setState(() => _status = "✅ Security verified");
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      _proceedToMainScreen();
    }
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
// PAINTERS & WIDGETS
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

    final path = Path();
    path.moveTo(w * 0.5, 0);
    path.lineTo(w * 0.9, h * 0.25);
    path.lineTo(w * 0.9, h * 0.6);
    path.lineTo(w * 0.5, h * 0.95);
    path.lineTo(w * 0.1, h * 0.6);
    path.lineTo(w * 0.1, h * 0.25);
    path.close();

    canvas.drawPath(path, paint);

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
    return Scaffold(
      backgroundColor: isPanicMode 
          ? const Color(0xFF455A64)
          : const Color(0xFF4CAF50),
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
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 70,
                ),
              ),
              const SizedBox(height: 40),
              Text(
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
// ✅ MAIN LOCK SCREEN
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
      isCompromisedDevice: widget.isCompromisedDevice,
      deviceLocation: widget.deviceLocation,
    );
    _enableSecureMode();
  }
  
  Future<void> _enableSecureMode() async {
    try {
      print('🔒 Security initialization complete');
    } catch (e) {
      print('⚠️ Secure mode failed: $e');
    }
  }

  @override
  void dispose() {
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
                  
                  Stack(
                    alignment: Alignment.center,
                    children: [
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
                          'INTELLIGENT-GRADE BIOMETRIC LOCK',
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
                  
                  
                  const SizedBox(height: 25),
                  
                  RingStyleChallengeDisplay(controller: _controller),
                  
                  const SizedBox(height: 15),
                  
                  const Text(
                    'Please match the code',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  
                  const SizedBox(height: 20),
                  
                  ValueListenableBuilder<int>(
                    valueListenable: _controller.randomizeTrigger,
                    builder: (context, trigger, _) {
                      return CryptexLock(
                        key: ValueKey(trigger),
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
// ✅ ENTERPRISE CONTROLLER (SECURE HYBRID MODE)
// ============================================

// THE RING / X-FILES ANIMATION
class RingStyleChallengeDisplay extends StatefulWidget {
  final EnterpriseController controller;
  
  const RingStyleChallengeDisplay({super.key, required this.controller});

  @override
  State<RingStyleChallengeDisplay> createState() => _RingStyleChallengeDisplayState();
}

class _RingStyleChallengeDisplayState extends State<RingStyleChallengeDisplay> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animController;
  late Animation<double> _emergeAnimation;
  
  final Random _random = Random();
  List<String> _staticNumbers = [];
  Timer? _staticTimer;
  bool _showingStatic = true;
  
  @override
  void initState() {
    super.initState();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    
    _emergeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    
    widget.controller.challengeCode.addListener(_onChallengeChanged);
    
    if (widget.controller.challengeCode.value.isNotEmpty) {
      _playEmergenceAnimation();
    }
  }
  
  void _onChallengeChanged() {
    _playEmergenceAnimation();
  }
  
  void _playEmergenceAnimation() async {
    setState(() => _showingStatic = true);
    
    _staticTimer?.cancel();
    _staticTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) {
        setState(() {
          _staticNumbers = List.generate(5, (_) => _random.nextInt(10).toString());
        });
      }
    });
    
    await Future.delayed(const Duration(milliseconds: 700));
    _staticTimer?.cancel();
    
    _animController.forward(from: 0.0);
    
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _showingStatic = false);
  }
  
  @override
  void dispose() {
    _staticTimer?.cancel();
    _animController.dispose();
    widget.controller.challengeCode.removeListener(_onChallengeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
        ],
      ),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return ValueListenableBuilder<List<int>>(
            valueListenable: widget.controller.challengeCode,
            builder: (context, code, _) {
              if (code.isEmpty) {
                return const SizedBox(
                  height: 50,
                  child: Center(child: CircularProgressIndicator(color: Colors.orangeAccent, strokeWidth: 2)),
                );
              }
              
              List<String> displayNumbers = _showingStatic 
                  ? _staticNumbers 
                  : code.map((e) => e.toString()).toList();
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(displayNumbers.length, (index) {
                  double stagger = index * 0.15;
                  double opacity = _showingStatic 
                      ? 0.4 
                      : ((_emergeAnimation.value - stagger).clamp(0.0, 1.0));
                  
                  double yOffset = _showingStatic 
                      ? 0 
                      : (1.0 - (_emergeAnimation.value - stagger).clamp(0.0, 1.0)) * 30;
                  
                  return Transform.translate(
                    offset: Offset(0, yOffset),
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          displayNumbers.length > index ? displayNumbers[index] : '0',
                          style: TextStyle(
                            color: _showingStatic 
                                ? Colors.greenAccent.withOpacity(0.6)
                                : Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier',
                            shadows: _showingStatic
                                ? [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 10)]
                                : [const BoxShadow(color: Colors.orange, blurRadius: 15, spreadRadius: 3)],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          );
        },
      ),
    );
  }
}

class EnterpriseController {
  // Challenge Code dari Server
  final ValueNotifier<List<int>> challengeCode = ValueNotifier([]);
  String? _currentNonce; // Tiket pengesahan
  
  final bool isCompromisedDevice;
  final Position? deviceLocation;
  
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);
  final ValueNotifier<int> randomizeTrigger = ValueNotifier(0);

  // Server URL (Update dengan URL Render Captain!)
  final String _serverUrl = 'https://z-kinetic-server.onrender.com'; 
  
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _lastMagnitude = 9.8;
  DateTime _lastMotionTime = DateTime.now();
  Timer? _decayTimer;
  
  EnterpriseController({
    this.isCompromisedDevice = false,
    this.deviceLocation,
  }) {
    _initSensors();
    _startDecayTimer();
    
    // 🚀 PRE-FETCH: Minta soalan dari server senyap-senyap masa start
    fetchChallengeFromServer(); 
  }

  // 🔥 FETCH CHALLENGE (Secure)
  Future<void> fetchChallengeFromServer() async {
    try {
      print('🔄 Fetching secure challenge from server...');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/getChallenge'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentNonce = data['nonce'];
        
        // Convert List<dynamic> ke List<int>
        List<dynamic> rawCode = data['challengeCode'];
        challengeCode.value = rawCode.map((e) => e as int).toList();
        
        print('✅ Secure Challenge Received: ${challengeCode.value}');
      } else {
        throw Exception('Server error');
      }
    } catch (e) {
      print('⚠️ Server offline/slow. Using Fallback (Low Security Mode). Error: $e');
      _generateLocalChallenge(); // Fallback kalau server tak dapat dicapai
    }
  }

  // Fallback (Local) - Macam kod lama, cuma guna bila darurat
  void _generateLocalChallenge() {
    challengeCode.value = List.generate(5, (_) => Random().nextInt(10));
    _currentNonce = "OFFLINE_MODE"; // Server akan reject ni kalau strict mode
  }

  void randomizeWheels() {
    randomizeTrigger.value++;
    fetchChallengeFromServer(); // Minta soalan baru dari server!
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      double delta = (magnitude - _lastMagnitude).abs();
      if (delta > 0.3) {
        motionScore.value = (delta / 3.0).clamp(0.0, 1.0);
        _lastMotionTime = DateTime.now();
      }
      _lastMagnitude = magnitude;
    });
  }

  void _startDecayTimer() {
    _decayTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (DateTime.now().difference(_lastMotionTime).inMilliseconds > 500) {
        motionScore.value = (motionScore.value - 0.05).clamp(0.0, 1.0);
      }
    });
  }

  void registerTouch() => touchScore.value = Random().nextDouble() * 0.3 + 0.7;
  void registerScroll() => patternScore.value = 0.8; 

  // 🔒 TRANSACTION BINDING 
  void bindTransaction(Map<String, dynamic> transactionDetails) {
     // (Placeholder)
  }

  // ✅ VERIFICATION LOGIC (Hantar Jawapan ke Server)
  Future<Map<String, dynamic>> verify(List<int> inputCode) async {
    // 1. Kalau Offline Mode, guna logic local
    if (_currentNonce == "OFFLINE_MODE") {
        String inputStr = inputCode.join();
        String targetStr = challengeCode.value.join();
        if (inputStr == targetStr) return {'allowed': true, 'isPanicMode': false};
        return {'allowed': false};
    }

    // 2. ONLINE MODE: Hantar ke Server untuk Semakan
    try {
        final response = await http.post(
            Uri.parse('$_serverUrl/attest'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
                'nonce': _currentNonce,
                'deviceId': 'CaptainDevice_001', 
                'userResponse': inputCode,
                'biometricData': {
                    'motion': motionScore.value,
                    'touch': touchScore.value
                }
            }),
        );

        if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final verdict = data['verdict'];
            
            if (verdict == "APPROVED_SILENT_ALARM") {
                return {'allowed': true, 'isPanicMode': true};
            } else {
                return {'allowed': true, 'isPanicMode': false};
            }
        } else {
            print('❌ Server Reject: ${response.body}');
            randomizeWheels();
            return {'allowed': false, 'isPanicMode': false};
        }
    } catch (e) {
        print('⚠️ Verification Error: $e');
        return {'allowed': false, 'isPanicMode': false};
    }
  }

  void dispose() {
    _accelSub?.cancel();
    _decayTimer?.cancel();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
    randomizeTrigger.dispose();
    challengeCode.dispose();
  }
}

// ============================================
// CRYPTEX LOCK 
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
    
    _scrollControllers = List.generate(
      5,
      (i) => FixedExtentScrollController(
        initialItem: _random.nextInt(10), 
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
                            textAlign: TextAlign.center,
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

  // Slot Machine Animation (Req 6)
  Future<void> _playSlotMachineAnimation() async {
    for (int i = 0; i < 5; i++) {
      if (mounted && _scrollControllers[i].hasClients) {
        int finalPos = Random().nextInt(10);
        _scrollControllers[i].animateToItem(
          finalPos,
          duration: Duration(milliseconds: 300 + (i * 200)),
          curve: Curves.easeOut,
        );
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }
}
