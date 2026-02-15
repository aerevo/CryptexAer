import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC PRODUK B - WITH CAPTAIN'S BEAUTIFUL UI!
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Using EXACT UI from Image 2 (right side screenshot)
// - z_wheel3.png image overlay
// - Beautiful challenge display
// - Professional cryptex wheels
// - All Captain's original styling!
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
// CONFIG (3-WHEEL ONLY)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticConfig {
  static const double imageWidth3 = 712.0;
  static const double imageHeight3 = 600.0;
  
  static const List<List<double>> coords3 = [
    [168, 158, 262, 384], 
    [309, 154, 403, 376], 
    [454, 150, 549, 379], 
  ];
  
  static const List<double> btnCoords3 = [113, 430, 605, 545];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DEMO SCREEN
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
    _controller = WidgetController(
      serverUrl: 'http://192.168.1.5:3000',  // ← GANTI URL CAPTAIN!
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
      _showDialog('🚫 Bot Detected', 'Purchase blocked for security.');
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
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _onPurchaseClick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                  ),
                  child: const Text(
                    'BUY TICKET',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          
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
// WIDGET CONTROLLER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WidgetController {
  final String serverUrl;
  
  String? _currentNonce;
  final ValueNotifier<List<int>> challengeCode = ValueNotifier([]);
  final ValueNotifier<int> randomizeTrigger = ValueNotifier(0);
  
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
          
          print('✅ Challenge: ${challengeCode.value}');
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
        return data;
      }
      
      return {'allowed': false, 'error': 'Server error'};
      
    } catch (e) {
      return {'allowed': false, 'error': 'Network error'};
    }
  }

  void registerTouch() => touchScore.value = Random().nextDouble() * 0.3 + 0.7;
  void registerScroll() => patternScore.value = 0.8;
  void randomizeWheels() => randomizeTrigger.value++;

  void dispose() {
    _accelSub?.cancel();
    challengeCode.dispose();
    randomizeTrigger.dispose();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC WIDGET (CAPTAIN'S BEAUTIFUL UI!)
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

class _ZKineticWidgetProdukBState extends State<ZKineticWidgetProdukB> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final success = await widget.controller.fetchChallenge();
    if (mounted) {
      setState(() => _loading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load challenge')),
        );
      }
    }
  }

  void _onVerify(List<int> userCode) async {
    setState(() => _loading = true);
    
    final result = await widget.controller.verify(userCode);
    
    widget.onComplete(result['allowed'] == true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
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
              
              const SizedBox(height: 12),
              
              // Subtitle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, color: Colors.greenAccent, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'BOT DETECTION',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 25),
              
              // Challenge Display
              VintageFilmChallengeDisplay(controller: widget.controller),
              
              const SizedBox(height: 15),
              
              const Text(
                'Please match the code',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Cryptex Lock (CAPTAIN'S BEAUTIFUL UI!)
              if (_loading)
                const CircularProgressIndicator(color: Colors.white)
              else
                ValueListenableBuilder<int>(
                  valueListenable: widget.controller.randomizeTrigger,
                  builder: (context, trigger, _) {
                    return CryptexLock(
                      key: ValueKey(trigger),
                      controller: widget.controller,
                      onSuccess: () => _onVerify([0, 0, 0]), // Placeholder
                      onFail: () {},
                    );
                  },
                ),
              
              const SizedBox(height: 20),
              
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// VINTAGE FILM CHALLENGE DISPLAY (From Captain's code!)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class VintageFilmChallengeDisplay extends StatelessWidget {
  final WidgetController controller;
  
  const VintageFilmChallengeDisplay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 55),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: ValueListenableBuilder<List<int>>(
        valueListenable: controller.challengeCode,
        builder: (context, code, _) {
          if (code.isEmpty) {
            return const SizedBox(
              height: 32,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.orangeAccent,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          
          return SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: code.map((digit) {
                return Container(
                  width: 24,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Text(
                    '$digit',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier',
                      height: 1.0,
                      shadows: [
                        BoxShadow(
                          color: Colors.orange,
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CRYPTEX LOCK (CAPTAIN'S BEAUTIFUL 3-WHEEL UI WITH z_wheel3.png!)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class CryptexLock extends StatefulWidget {
  final WidgetController controller;
  final VoidCallback onSuccess;
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
  static const double imageWidth = ZKineticConfig.imageWidth3;
  static const double imageHeight = ZKineticConfig.imageHeight3;
  static const List<List<double>> wheelCoords = ZKineticConfig.coords3;
  static const List<double> buttonCoords = ZKineticConfig.btnCoords3;

  late List<FixedExtentScrollController> _scrollControllers;
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  bool _isButtonPressed = false;
  
  final Random _random = Random();
  late Timer _driftTimer;
  late List<Offset> _textDriftOffsets;
  late List<AnimationController> _opacityControllers;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    
    _scrollControllers = List.generate(
      3,
      (i) => FixedExtentScrollController(initialItem: _random.nextInt(10)),
    );
    
    _textDriftOffsets = List.generate(3, (_) => Offset.zero);

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
      widget.onSuccess();
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
              // Background image (z_wheel3.png)
              Positioned.fill(
                child: Image.asset(
                  'assets/z_wheel3.png',
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
      child: ListWheelScrollView.useDelegate(
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
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Text(
                          '$displayNumber',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: wheelHeight * 0.30,
                            fontWeight: FontWeight.w900,
                            color: isActive 
                                ? const Color(0xFFFF5722)
                                : const Color(0xFF263238),
                            height: 1.0,
                            shadows: isActive
                                ? [
                                    Shadow(
                                      color: const Color(0xFFFF5722).withOpacity(0.8),
                                      blurRadius: 20,
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
                      BoxShadow(
                        color: const Color(0xFFFF5722).withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 5,
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
