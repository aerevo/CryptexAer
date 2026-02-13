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
// CONFIGURATION: DUAL MODE DATA
// ============================================
enum WheelMode { threeWheel, fiveWheel }

class ZKineticConfig {
  static const double imageWidth3 = 712.0;
  static const double imageHeight3 = 600.0;
  
  static const double imageWidth5 = 706.0;
  static const double imageHeight5 = 610.0;

  // Koordinat 3 Roda (Baru)
  static const List<List<double>> coords3 = [
    [168, 158, 262, 384], 
    [309, 154, 403, 376], 
    [454, 150, 549, 379], 
  ];
  static const List<double> btnCoords3 = [113, 430, 605, 545];

  // Koordinat 5 Roda (Lama)
  static const List<List<double>> coords5 = [
    [25, 159, 113, 378],
    [165, 160, 257, 379],
    [308, 160, 396, 379],
    [448, 159, 541, 378],
    [591, 159, 681, 379],
  ];
  static const List<double> btnCoords5 = [123, 433, 594, 545];
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
  String _status = "Initializing dual-mode system...";
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
    
    setState(() => _status = "Loading engine...");
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
              ElevatedButton(
                onPressed: _requestLocationAndProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text(
                  'Authorize & Proceed',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
    final Color themeColor = isPanicMode ? Colors.orange : const Color(0xFF00E676);
    final IconData iconData = isPanicMode ? Icons.warning_amber_rounded : Icons.lock_open_rounded;
    final String titleText = isPanicMode ? 'SILENT ALARM' : 'ACCESS GRANTED';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 25),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: themeColor, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeColor.withOpacity(0.15),
                Colors.black.withOpacity(0.8),
              ],
            ),
            boxShadow: [
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeColor.withOpacity(0.1),
                  border: Border.all(color: themeColor.withOpacity(0.5), width: 1),
                ),
                child: Icon(iconData, size: 60, color: themeColor),
              ),
              const SizedBox(height: 30),
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
                  ),
                  child: const Text(
                    'PROCEED',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
// MAIN LOCK SCREEN (DUAL MODE)
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

  void _toggleMode() {
    _controller.toggleWheelMode();
    setState(() {}); // Rebuild UI
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _controller.currentMode == WheelMode.threeWheel 
            ? 'SWITCHED TO 3-WHEEL MODE (FAST)' 
            : 'SWITCHED TO 5-WHEEL MODE (SECURE)'
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFFFF5722),
      ),
    );
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
          // GEAR ICON FOR MODE SWITCHING
          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70, size: 28),
              onPressed: _toggleMode,
            ),
          ),

          Center(
            child: Container(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
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
                  // TITLE HEADER
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
                          colors: [Color(0xFFFFFFFF), Color(0xFFFFCCBC)],
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
                  
                  // SUBTITLE PILL
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
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _controller.currentMode == WheelMode.threeWheel
                              ? '3-FACTOR BIOMETRIC LOCK'
                              : '5-FACTOR ENTERPRISE LOCK',
                          style: const TextStyle(
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
                  
                  // 🔥 DYNAMIC CHALLENGE DISPLAY (3 OR 5 DIGITS)
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
                  
                  // 🔥 DYNAMIC WHEEL LOCK (3 OR 5 WHEELS)
                  ValueListenableBuilder<int>(
                    valueListenable: _controller.randomizeTrigger,
                    builder: (context, trigger, _) {
                      return CryptexLock(
                        key: ValueKey("${_controller.currentMode}_$trigger"), // Force rebuild on mode switch
                        controller: _controller,
                        onSuccess: _onSuccess,
                        onFail: _onFail,
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // STATUS INDICATORS
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
// VISUAL: LINKIN PARK GLITCH (DUAL MODE SUPPORT)
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
  List<String> _displayNumbers = []; 
  Timer? _sequenceTimer;
  
  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..repeat(reverse: true);
    
    // Init display numbers based on current mode length
    int length = widget.controller.currentMode == WheelMode.threeWheel ? 3 : 5;
    _displayNumbers = List.generate(length, (index) => '0');

    widget.controller.challengeCode.addListener(_onChallengeChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _startChaosSequence();
    });
  }
  
  void _onChallengeChanged() {
    if (mounted) {
      // Update display list size if mode changed
      int requiredLen = widget.controller.currentMode == WheelMode.threeWheel ? 3 : 5;
      if (_displayNumbers.length != requiredLen) {
        setState(() {
          _displayNumbers = List.generate(requiredLen, (index) => '0');
        });
      }
      _startChaosSequence();
    }
  }
  
  void _startChaosSequence() async {
    _sequenceTimer?.cancel();
    if (mounted) setState(() => _activeGlitchIndex = -1);

    List<int> targetCode = widget.controller.challengeCode.value;
    int digitCount = widget.controller.currentMode == WheelMode.threeWheel ? 3 : 5;

    // Fallback if empty
    if (targetCode.isEmpty) {
       targetCode = widget.controller.currentMode == WheelMode.threeWheel 
           ? [8, 2, 9] 
           : [8, 3, 9, 1, 4];
    }

    _sequenceTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      
      setState(() {
        _activeGlitchIndex = _random.nextInt(digitCount);
        // Safety check index bounds
        if (_activeGlitchIndex < targetCode.length) {
            _displayNumbers[_activeGlitchIndex] = targetCode[_activeGlitchIndex].toString();
        }
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
    int digitCount = widget.controller.currentMode == WheelMode.threeWheel ? 3 : 5;

    return Transform.scale(
      scale: 0.85, 
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
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
          children: List.generate(digitCount, (index) { 
            bool isGlitching = index == _activeGlitchIndex;
            bool hasRevealed = true; 

            // Safety check for display numbers list
            String textToDisplay = (index < _displayNumbers.length) 
                ? _displayNumbers[index] 
                : '0';

            return _buildLinkinParkDigit(
              text: hasRevealed ? textToDisplay : _random.nextInt(10).toString(),
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
// ENTERPRISE CONTROLLER (DUAL MODE LOGIC)
// ============================================
class EnterpriseController {
  WheelMode currentMode = WheelMode.threeWheel; // Default start with 3-wheel

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

  void toggleWheelMode() {
    currentMode = (currentMode == WheelMode.threeWheel) 
        ? WheelMode.fiveWheel 
        : WheelMode.threeWheel;
    
    // Refresh challenge immediately
    randomizeWheels();
  }

  Future<void> fetchChallengeFromServer() async {
    try {
      print('🔄 Fetching challenge for mode: $currentMode');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/getChallenge'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _currentNonce = data['nonce'];
          
          List<dynamic> rawCode = data['challengeCode'];
          // Adapt to mode
          int count = currentMode == WheelMode.threeWheel ? 3 : 5;
          challengeCode.value = rawCode.take(count).map((e) => e as int).toList();
          
          print('✅ Challenge: ${challengeCode.value}');
        } else {
          throw Exception('Server returned success=false');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Fallback Local Challenge');
      _generateLocalChallenge();
    }
  }

  void _generateLocalChallenge() {
    int count = currentMode == WheelMode.threeWheel ? 3 : 5;
    challengeCode.value = List.generate(count, (_) => Random().nextInt(10));
    _currentNonce = "OFFLINE_MODE";
  }

  void randomizeWheels() {
    randomizeTrigger.value++; 
    fetchChallengeFromServer(); 
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

  Future<Map<String, dynamic>> verify(List<int> inputCode) async {
    // Basic verification
    String inputStr = inputCode.join();
    String targetStr = challengeCode.value.join();
    String panicStr = challengeCode.value.reversed.join();

    if (inputStr == panicStr) {
      return {'allowed': true, 'isPanicMode': true};
    }

    bool motionOK = motionScore.value > 0.15;
    bool codeCorrect = inputStr == targetStr;

    if (codeCorrect && motionOK) {
      return {'allowed': true, 'isPanicMode': false};
    } else {
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
// CRYPTEX LOCK (DUAL MODE ENGINE)
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
  late List<FixedExtentScrollController> _scrollControllers;

  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool _isButtonPressed = false;
  
  final Random _random = Random();
  late Timer _driftTimer;
  late List<Offset> _textDriftOffsets;
  
  late List<AnimationController> _opacityControllers;
  late List<Animation<double>> _opacityAnimations;

  // Helpers to get current config
  WheelMode get mode => widget.controller.currentMode;
  int get wheelCount => mode == WheelMode.threeWheel ? 3 : 5;
  double get imgWidth => mode == WheelMode.threeWheel ? ZKineticConfig.imageWidth3 : ZKineticConfig.imageWidth5;
  double get imgHeight => mode == WheelMode.threeWheel ? ZKineticConfig.imageHeight3 : ZKineticConfig.imageHeight5;
  String get imgAsset => mode == WheelMode.threeWheel ? 'assets/z_wheel3.png' : 'assets/z_wheel.png';
  List<List<double>> get coords => mode == WheelMode.threeWheel ? ZKineticConfig.coords3 : ZKineticConfig.coords5;
  List<double> get btnCoords => mode == WheelMode.threeWheel ? ZKineticConfig.btnCoords3 : ZKineticConfig.btnCoords5;

  @override
  void initState() {
    super.initState();
    
    // Initialize list based on current mode
    _scrollControllers = List.generate(
      wheelCount,
      (i) => FixedExtentScrollController(initialItem: _random.nextInt(10)),
    );
    
    _textDriftOffsets = List.generate(wheelCount, (_) => Offset.zero);

    _driftTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted && _activeWheelIndex == null) {
        setState(() {
          for (int i = 0; i < wheelCount; i++) {
            _textDriftOffsets[i] = Offset(
              (_random.nextDouble() - 0.5) * 2.5,
              (_random.nextDouble() - 0.5) * 2.5,
            );
          }
        });
      }
    });
    
    _opacityControllers = List.generate(wheelCount, (i) {
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
      await _playSlotMachineAnimation();
    }
  }

  Future<void> _playSlotMachineAnimation() async {
    for (int i = 0; i < wheelCount; i++) {
      if (!mounted) continue;
      _scrollControllers[i].animateToItem(
        _scrollControllers[i].selectedItem + 500, 
        duration: const Duration(seconds: 10), 
        curve: Curves.linear, 
      );
    }

    for (int i = 0; i < wheelCount; i++) {
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
        // Calculate aspect ratio dynamically based on current image
        double aspectRatio = imgWidth / imgHeight;
        double calculatedHeight = availableWidth / aspectRatio;

        return SizedBox(
          width: availableWidth,
          height: calculatedHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  imgAsset, // Dynamic Image (3 or 5)
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
    // Dynamic Coords
    List<List<double>> currentCoords = coords;

    for (int i = 0; i < currentCoords.length; i++) {
      double left = currentCoords[i][0];
      double top = currentCoords[i][1];
      double right = currentCoords[i][2];
      double bottom = currentCoords[i][3];

      double actualLeft = screenWidth * (left / imgWidth);
      double actualTop = screenHeight * (top / imgHeight);
      double actualWidth = screenWidth * ((right - left) / imgWidth);
      double actualHeight = screenHeight * ((bottom - top) / imgHeight);

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
    // Dynamic Button Coords
    List<double> currentBtnCoords = btnCoords;

    double left = currentBtnCoords[0];
    double top = currentBtnCoords[1];
    double right = currentBtnCoords[2];
    double bottom = currentBtnCoords[3];

    double actualLeft = screenWidth * (left / imgWidth);
    double actualTop = screenHeight * (top / imgHeight);
    double actualWidth = screenWidth * ((right - left) / imgWidth);
    double actualHeight = screenHeight * ((bottom - top) / imgHeight);

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
