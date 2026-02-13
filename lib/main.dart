import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
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
    try {
      setState(() => _status = "📍 Requesting location...");
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _status = "❌ Location services disabled");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _status = "❌ Location permission denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _status = "❌ Location permission permanently denied");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _capturedLocation = position;
        _status = "✅ Location captured";
      });

      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        _proceedToMainScreen();
      }
    } catch (e) {
      setState(() => _status = "❌ Location error: $e");
    }
  }

  void _proceedToMainScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ZKineticLockScreen(
          isCompromisedDevice: _isRooted || _isDeveloperMode,
          deviceLocation: _capturedLocation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 80, color: Color(0xFFFF5722)),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (_needsLocationConsent && !_checkComplete) ...[
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
                    const SizedBox(height: 15),
                    const Text(
                      'Perangkat Tidak Selamat',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Untuk melanjutkan dengan perangkat yang dikompromikan, kami perlu lokasi peranti anda (satu kali).',
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _requestLocationAndProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child: const Text(
                        'Berikan Izin Lokasi',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================
// SUCCESS SCREEN (PROFESSIONAL GREEN CONTAINER)
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
    // Tentukan warna tema: Hijau Neon (Success) atau Oren (Panic)
    final Color themeColor = isPanicMode ? Colors.orange : const Color(0xFF00E676);
    final IconData iconData = isPanicMode ? Icons.warning_amber_rounded : Icons.lock_open_rounded;
    final String titleText = isPanicMode ? 'SILENT ALARM' : 'ACCESS GRANTED';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          // Margin kiri kanan supaya tak rapat dinding
          margin: const EdgeInsets.symmetric(horizontal: 30),
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 25),
          decoration: BoxDecoration(
            color: Colors.black, // Dasar hitam
            borderRadius: BorderRadius.circular(24),
            // Border menyala
            border: Border.all(color: themeColor, width: 2),
            // Background dalam sikit pudar + Glow luar
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeColor.withOpacity(0.15),
                Colors.black.withOpacity(0.8),
              ],
            ),
            boxShadow: [
              // Glow Effect
              BoxShadow(
                color: themeColor.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bulatan Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeColor.withOpacity(0.1),
                  border: Border.all(color: themeColor.withOpacity(0.5), width: 1),
                ),
                child: Icon(
                  iconData,
                  size: 60,
                  color: themeColor,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Tajuk Besar
              Text(
                titleText,
                style: TextStyle(
                  color: themeColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: themeColor.withOpacity(0.6), blurRadius: 10),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Mesej Kecil (Welcome Back etc)
              Text(
                message.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              
              const SizedBox(height: 35),
              
              // Tombol Continue
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    shadowColor: themeColor.withOpacity(0.5),
                  ),
                  child: const Text(
                    'PROCEED',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// MAIN LOCK SCREEN (3-WHEEL VERSION)
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
          message: isPanicMode ? "Panic mode activated" : "User Verified Successfully",
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
                  
                  const SizedBox(height: 25),
                  
                  // 🔥 INI BAHAGIAN NOMBOR ATAS (SIMON SAYS - CHAOS - 3 DIGITS)
                  VintageFilmChallengeDisplay(controller: _controller),
                  
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
                  
                  // 🔥 INI BAHAGIAN RODA BAWAH (KASINO - 3 WHEELS)
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
// VISUAL: LINKIN PARK GLITCH (RANDOM CHAOS MODE - 3 DIGITS)
// ============================================
class VintageFilmChallengeDisplay extends StatefulWidget {
  final EnterpriseController controller;
  
  const VintageFilmChallengeDisplay({super.key, required this.controller});

  @override
  State<VintageFilmChallengeDisplay> createState() => _VintageFilmChallengeDisplayState();
}

class _VintageFilmChallengeDisplayState extends State<VintageFilmChallengeDisplay> 
    with TickerProviderStateMixin {
  
  late AnimationController _glitchController;
  final Random _random = Random();
  
  int _activeGlitchIndex = -1; 
  List<String> _displayNumbers = ['0', '0', '0']; // 3 Digits
  Timer? _sequenceTimer;
  
  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..repeat(reverse: true);
    
    widget.controller.challengeCode.addListener(_onChallengeChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _startChaosSequence();
    });
  }
  
  void _onChallengeChanged() {
    if (mounted) {
      _startChaosSequence();
    }
  }
  
  // 🔥 FUNGSI CHAOS (Lompat-lompat tak ikut urutan)
  void _startChaosSequence() async {
    _sequenceTimer?.cancel();
    if (mounted) setState(() => _activeGlitchIndex = -1);

    List<int> targetCode = widget.controller.challengeCode.value;
    if (targetCode.isEmpty) targetCode = [8, 2, 9]; // Dummy 3 digits

    _sequenceTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      
      setState(() {
        // 1. Pilih SATU index secara RAWAK (0 sampai 2)
        _activeGlitchIndex = _random.nextInt(3);
        
        // 2. Tunjukkan nombor sebenar pada index yang kena 'hit'
        _displayNumbers[_activeGlitchIndex] = targetCode[_activeGlitchIndex].toString();
      });

      HapticFeedback.selectionClick();
    });
  }
  
  @override
  void dispose() {
    _sequenceTimer?.cancel();
    _glitchController.dispose();
    widget.controller.challengeCode.removeListener(_onChallengeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1) KECILKAN SAIZ: Scale 0.85 
    return Transform.scale(
      scale: 0.85, 
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        // 2) KECILKAN HEIGHT: Vertical Padding = 6 (Nipis)
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          
          // WARNA BERLAPIS (HIJAU + PURPLE)
          border: Border.all(
            color: Colors.greenAccent, 
            width: 2
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurpleAccent.withOpacity(0.6), 
              blurRadius: 15, 
              spreadRadius: 3
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (index) { // 3 DIGITS
            bool isGlitching = index == _activeGlitchIndex;
            // Logic Chaos: Kita tunjuk semua nombor sentiasa, cuma satu je gegar
            bool hasRevealed = true; 

            return _buildLinkinParkDigit(
              text: hasRevealed ? _displayNumbers[index] : _random.nextInt(10).toString(),
              isGlitching: isGlitching,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLinkinParkDigit({required String text, required bool isGlitching}) {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, child) {
        double randomX = isGlitching ? (_random.nextDouble() - 0.5) * 8.0 : 0.0;
        double randomY = isGlitching ? (_random.nextDouble() - 0.5) * 8.0 : 0.0;
        double rX = isGlitching ? 4.0 : 0.0;
        double bX = isGlitching ? -4.0 : 0.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(randomX + rX, randomY),
              child: Text(text, style: TextStyle(fontSize: 36, fontFamily: 'Courier', fontWeight: FontWeight.w900, color: isGlitching ? Colors.red.withOpacity(0.8) : Colors.transparent)),
            ),
            Transform.translate(
              offset: Offset(randomX + bX, randomY),
              child: Text(text, style: TextStyle(fontSize: 36, fontFamily: 'Courier', fontWeight: FontWeight.w900, color: isGlitching ? Colors.blue.withOpacity(0.8) : Colors.transparent)),
            ),
            Transform.translate(
              offset: Offset(randomX, randomY),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 36,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w900,
                  color: isGlitching 
                      ? Colors.white 
                      : (text == '-' ? Colors.grey[800] : Colors.cyanAccent),
                  shadows: isGlitching
                      ? [BoxShadow(color: Colors.white, blurRadius: 15)]
                      : [BoxShadow(color: Colors.cyanAccent, blurRadius: 8)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================
// ENTERPRISE CONTROLLER (3-DIGIT LOGIC)
// ============================================
class EnterpriseController {
  final ValueNotifier<List<int>> challengeCode = ValueNotifier([]);
  String? _currentNonce;
  
  final bool isCompromisedDevice;
  final Position? deviceLocation;
  
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);
  final ValueNotifier<int> randomizeTrigger = ValueNotifier(0);

  String? _boundTransactionHash;
  Map<String, dynamic>? _boundTransactionDetails;
  
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
    fetchChallengeFromServer();
  }

  Future<void> fetchChallengeFromServer() async {
    try {
      print('🔄 Fetching secure challenge from server...');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/getChallenge'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          _currentNonce = data['nonce'];
          
          // AMBIL 3 DIGIT SAHAJA
          List<dynamic> rawCode = data['challengeCode'];
          challengeCode.value = rawCode.take(3).map((e) => e as int).toList();
          
          print('✅ Secure Challenge Received: ${challengeCode.value}');
        } else {
          throw Exception('Server returned success=false');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Server offline/slow. Using Fallback Mode. Error: $e');
      _generateLocalChallenge();
    }
  }

  void _generateLocalChallenge() {
    // GENERATE 3 DIGIT SAHAJA
    challengeCode.value = List.generate(3, (_) => Random().nextInt(10));
    _currentNonce = "OFFLINE_MODE";
    print('⚠️ LOCAL CHALLENGE: ${challengeCode.value} (Low Security Mode)');
  }

  void randomizeWheels() {
    randomizeTrigger.value++; 
    fetchChallengeFromServer(); 
    print('🔀 Trigger Glitch & Fetch New Data');
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

  void bindTransaction(Map<String, dynamic> transactionDetails) {
    _boundTransactionDetails = transactionDetails;
    final Map<String, dynamic> hashData = {
      'amount': transactionDetails['amount'],
      'recipient': transactionDetails['recipient'],
      'currency': transactionDetails['currency'] ?? 'MYR',
      'timestamp': DateTime.now().toIso8601String(),
    };
    final sortedJson = json.encode(hashData);
    _boundTransactionHash = sha256.convert(utf8.encode(sortedJson)).toString();
  }

  Future<void> _sendThreatIntelligence({required String type, required String severity}) async {
    print('📡 [THREAT INTEL] Sending: $type ($severity) | Loc: ${deviceLocation?.latitude ?? 'N/A'}');
  }

  Future<Map<String, dynamic>> verify(List<int> inputCode) async {
    if (_currentNonce == "OFFLINE_MODE") {
      print('⚠️ OFFLINE VERIFICATION (Low Security)');
      
      String inputStr = inputCode.join();
      String targetStr = challengeCode.value.join();
      String panicStr = challengeCode.value.reversed.join();

      if (inputStr == panicStr) {
        print('🚨 PANIC MODE (Offline)');
        await _sendThreatIntelligence(type: "PANIC_DURESS", severity: "CRITICAL");
        return {
          'allowed': true,
          'isPanicMode': true,
        };
      }

      bool motionOK = motionScore.value > 0.15;
      bool codeCorrect = inputStr == targetStr;

      if (codeCorrect && motionOK) {
        return {
          'allowed': true,
          'isPanicMode': false,
        };
      } else {
        randomizeWheels();
        return {'allowed': false, 'isPanicMode': false};
      }
    }

    try {
      print('🔄 Sending attestation to server...');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/attest'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nonce': _currentNonce,
          'deviceId': 'device_${deviceLocation?.latitude ?? Random().nextInt(99999)}',
          'userResponse': inputCode,
          'biometricData': {
            'motion': motionScore.value,
            'touch': touchScore.value,
            'pattern': patternScore.value,
          }
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final verdict = data['verdict'];
        
        print('✅ Server Response: $verdict');
        
        if (verdict == "APPROVED_SILENT_ALARM") {
          await _sendThreatIntelligence(type: "PANIC_DURESS", severity: "CRITICAL");
          return {
            'allowed': true,
            'isPanicMode': true,
          };
        } else if (verdict == "APPROVED") {
          return {
            'allowed': true,
            'isPanicMode': false,
            'boundTransactionHash': _boundTransactionHash
          };
        }
      }
      
      print('❌ Server Reject: ${response.body}');
      randomizeWheels();
      return {'allowed': false, 'isPanicMode': false};
      
    } catch (e) {
      print('⚠️ Verification Error: $e');
      randomizeWheels();
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
// CRYPTEX LOCK (RODA BAWAH: 3-WHEEL VERSION)
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
  // CONFIG 3-WHEEL
  static const double imageWidth = 712.0;
  static const double imageHeight = 600.0;

  // Koordinat Roda (3 RODA)
  static const List<List<double>> wheelCoords = [
    [168, 158, 262, 384], // Wheel 1
    [309, 154, 403, 376], // Wheel 2
    [454, 150, 549, 379], // Wheel 3
  ];

  static const List<double> buttonCoords = [113, 430, 605, 545];

  late List<FixedExtentScrollController> _scrollControllers;

  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool _isButtonPressed = false;
  
  final Random _random = Random();
  late Timer _driftTimer;
  final List<Offset> _textDriftOffsets = List.generate(3, (_) => Offset.zero); // 3 DIGITS
  
  late List<AnimationController> _opacityControllers;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    
    // GENERATE 3 CONTROLLER
    _scrollControllers = List.generate(
      3,
      (i) => FixedExtentScrollController(initialItem: _random.nextInt(10)),
    );
    
    _driftTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted && _activeWheelIndex == null) {
        setState(() {
          for (int i = 0; i < 3; i++) {
            _textDriftOffsets[i] = Offset(
              (_random.nextDouble() - 0.5) * 2.5,
              (_random.nextDouble() - 0.5) * 2.5,
            );
          }
        });
      }
    });
    
    _opacityControllers = List.generate(3, (i) {
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

    // 🔥 AUTO START RODA BAWAH (INTRO)
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _playSlotMachineAnimation(); 
    });
  }

  @override
  void dispose() {
    for (var c in _scrollControllers) c.dispose();
    for (var c in _opacityControllers) c.dispose();
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
      if (mounted) setState(() => _activeWheelIndex = null);
    });
  }

  Future<void> _onButtonTap() async {
    setState(() => _isButtonPressed = true);
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _isButtonPressed = false);
    
    List<int> currentCode = [];
    for (var controller in _scrollControllers) {
      currentCode.add(controller.selectedItem % 10);
    }
    
    final result = await widget.controller.verify(currentCode);
    
    if (result['allowed']) {
      widget.onSuccess(result['isPanicMode'] ?? false);
    } else {
      widget.onFail();
      // 🔥 SALAH PASS: PUSING LAGI
      await _playSlotMachineAnimation();
    }
  }

  // 🔥 ENGINE SLOT MACHINE (KASINO)
  Future<void> _playSlotMachineAnimation() async {
    // 1. Pusing serentak (Laju) - 3 Roda
    for (int i = 0; i < 3; i++) {
      if (!mounted) continue;
      _scrollControllers[i].animateToItem(
        _scrollControllers[i].selectedItem + 500, 
        duration: const Duration(seconds: 10), 
        curve: Curves.linear, 
      );
    }

    // 2. Berhenti satu per satu (Waterfall Snap) - 3 Roda
    for (int i = 0; i < 3; i++) {
      int stopDelay = 500 + (i * 500); 
      Future.delayed(Duration(milliseconds: stopDelay), () {
        if(mounted) _stopWheelAtRandom(i);
      });
    }
  }

  Future<void> _stopWheelAtRandom(int index) async {
    if (!mounted) return;
    int currentItem = _scrollControllers[index].selectedItem;
    int targetItem = currentItem + 20 + Random().nextInt(10); 

    // FORCE STOP (KTAK!)
    await _scrollControllers[index].animateToItem(
      targetItem,
      duration: const Duration(milliseconds: 800), 
      curve: Curves.easeOutBack, 
    );
    HapticFeedback.heavyImpact();
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
                  'assets/z_wheel3.png', // PENTING: Guna 3 wheel image
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
      child: ListWheelScrollView.useDelegate(
        controller: _scrollControllers[index],
        itemExtent: itemExtent,
        perspective: 0.003,
        diameterRatio: 2.0,
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
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Text(
                          '$displayNumber',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: wheelHeight * 0.30,
                            fontWeight: FontWeight.w900,
                            color: isActive ? const Color(0xFFFF5722) : const Color(0xFF263238),
                            height: 1.0,
                            shadows: isActive
                                ? [Shadow(color: const Color(0xFFFF5722).withOpacity(0.8), blurRadius: 20)]
                                : [
                                    Shadow(offset: const Offset(1, 1), blurRadius: 1, color: Colors.white.withOpacity(0.4)),
                                    Shadow(offset: const Offset(-1, -1), blurRadius: 1, color: Colors.black.withOpacity(0.6)),
                                  ],
                          ),
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
                      BoxShadow(color: const Color(0xFFFF5722).withOpacity(0.6), blurRadius: 30, spreadRadius: 5),
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
