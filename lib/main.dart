import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC PRODUK B - CASINO RETRY EDITION
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ✅ FEATURE: WRONG PASSWORD = AUTO RESPIN (SLOT MACHINE STYLE)
// ✅ INTRO: Slot Machine Spin on start
// ✅ FX: All Glitch/Drift/Glow effects included
// ✅ FIXED: Magenta Color Error
// ✅ SERVER: http://100.70.65.8:3000
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
// CONFIG
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
      serverUrl: 'http://100.70.65.8:3000', // DO NOT CHANGE!
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
                const Text('Concert Tickets', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('BTS World Tour 2026', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 40),
                const Text('RM 299', style: TextStyle(fontSize: 48, color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _onPurchaseClick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                  ),
                  child: const Text('BUY TICKET', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
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
  DateTime _lastMotionTime = DateTime.now();
  Timer? _decayTimer;
  
  WidgetController({required this.serverUrl}) {
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
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Network error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> verify(List<int> userResponse) async {
    if (_currentNonce == null) return {'allowed': false, 'error': 'No active challenge'};
    
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

      if (response.statusCode == 200) return json.decode(response.body);
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
    _decayTimer?.cancel();
    challengeCode.dispose();
    randomizeTrigger.dispose();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Z-KINETIC WIDGET
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
    if (mounted) setState(() => _loading = false);
  }

  void _onSuccess(bool isPanicMode) {
    widget.onComplete(true);
  }

  void _onFail() {
    // 🛑 DONT CLOSE! Just let the user retry with new spin
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
              const Text('Z-KINETIC', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4)),
              const SizedBox(height: 12),
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
                    Text('INTELLIGENT-GRADE BIOMETRIC LOCK', style: TextStyle(fontSize: 9, color: Colors.white, letterSpacing: 1, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              UltimateRGBGlitchDisplay(controller: widget.controller),
              const SizedBox(height: 15),
              const Text('Please match the code', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(padding: EdgeInsets.all(50.0), child: CircularProgressIndicator(color: Colors.white))
              else
                ValueListenableBuilder<int>(
                  valueListenable: widget.controller.randomizeTrigger,
                  builder: (context, trigger, _) {
                    return UltimateCryptexLock(
                      key: ValueKey(trigger),
                      controller: widget.controller,
                      onSuccess: _onSuccess,
                      onFail: _onFail,
                    );
                  },
                ),
              const SizedBox(height: 15),
              UltimateBiometricPanel(controller: widget.controller),
              const SizedBox(height: 15),
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
// RGB GLITCH
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class UltimateRGBGlitchDisplay extends StatefulWidget {
  final WidgetController controller;
  const UltimateRGBGlitchDisplay({super.key, required this.controller});

  @override
  State<UltimateRGBGlitchDisplay> createState() => _UltimateRGBGlitchDisplayState();
}

class _UltimateRGBGlitchDisplayState extends State<UltimateRGBGlitchDisplay> {
  Timer? _glitchTimer;
  double _xOffset = 0;
  double _yOffset = 0;
  bool _isGlitching = false;
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _glitchTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_rnd.nextDouble() > 0.7) {
        setState(() {
          _isGlitching = true;
          _xOffset = (_rnd.nextDouble() - 0.5) * 4;
          _yOffset = (_rnd.nextDouble() - 0.5) * 3;
        });
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) setState(() => _isGlitching = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _glitchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 55),
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.6), width: 2),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 12)],
      ),
      child: ValueListenableBuilder<List<int>>(
        valueListenable: widget.controller.challengeCode,
        builder: (context, code, _) {
          if (code.isEmpty) return const Center(child: Text("...", style: TextStyle(color: Colors.white, fontSize: 32)));
          String codeStr = code.join('  ');
          return Stack(
            alignment: Alignment.center,
            children: [
              if (_isGlitching) Transform.translate(offset: Offset(_xOffset + 2, _yOffset), child: Text(codeStr, style: _glitchStyle(Colors.cyan))),
              if (_isGlitching) Transform.translate(offset: Offset(-_xOffset - 2, -_yOffset), child: Text(codeStr, style: _glitchStyle(const Color(0xFFFF00FF)))),
              Text(codeStr, style: _glitchStyle(Colors.white)),
            ],
          );
        },
      ),
    );
  }

  TextStyle _glitchStyle(Color color) => TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Courier', letterSpacing: 4, color: color);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BIOMETRIC PANEL
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class UltimateBiometricPanel extends StatelessWidget {
  final WidgetController controller;
  const UltimateBiometricPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(color: const Color(0xFFFF5722), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIndicator(icon: Icons.sensors, label: 'MOTION', valueNotifier: controller.motionScore),
          _buildIndicator(icon: Icons.touch_app, label: 'TOUCH', valueNotifier: controller.touchScore),
          _buildIndicator(icon: Icons.fingerprint, label: 'PATTERN', valueNotifier: controller.patternScore),
        ],
      ),
    );
  }

  Widget _buildIndicator({required IconData icon, required String label, required ValueNotifier<double> valueNotifier}) {
    return ValueListenableBuilder<double>(
      valueListenable: valueNotifier,
      builder: (context, value, _) {
        bool isActive = value > 0.5;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isActive ? Colors.greenAccent : Colors.white30),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 8, color: isActive ? Colors.greenAccent : Colors.white30, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CRYPTEX LOCK (SLOT MACHINE + AUTO RESPIN ON FAIL)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class UltimateCryptexLock extends StatefulWidget {
  final WidgetController controller;
  final Function(bool) onSuccess;
  final VoidCallback onFail;

  const UltimateCryptexLock({super.key, required this.controller, required this.onSuccess, required this.onFail});

  @override
  State<UltimateCryptexLock> createState() => _UltimateCryptexLockState();
}

class _UltimateCryptexLockState extends State<UltimateCryptexLock> with TickerProviderStateMixin {
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
    _scrollControllers = List.generate(3, (i) => FixedExtentScrollController(initialItem: 0));
    
    // 🔥 AUTO PLAY INTRO ON START
    WidgetsBinding.instance.addPostFrameCallback((_) => _playSlotMachineIntro());

    _textDriftOffsets = List.generate(3, (_) => Offset.zero);
    _driftTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted && _activeWheelIndex == null) {
        setState(() {
          for (int i = 0; i < 3; i++) {
            _textDriftOffsets[i] = Offset((_random.nextDouble() - 0.5) * 2.5, (_random.nextDouble() - 0.5) * 2.5);
          }
        });
      }
    });
    
    _opacityControllers = List.generate(3, (i) {
      final controller = AnimationController(vsync: this, duration: Duration(milliseconds: 1800 + (_random.nextInt(400))));
      Future.delayed(Duration(milliseconds: _random.nextInt(1000)), () { if (mounted) controller.repeat(reverse: true); });
      return controller;
    });
    _opacityAnimations = _opacityControllers.map((c) => Tween<double>(begin: 0.75, end: 1.0).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();
  }

  // 🔥 RESPIN ANIMATION
  void _playSlotMachineIntro() {
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: 200 + (i * 300)), () { // Faster interval for re-try
        if (!mounted) return;
        int target = 20 + _random.nextInt(10); 
        _scrollControllers[i].animateToItem(
          target,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.elasticOut,
        );
        Future.delayed(const Duration(milliseconds: 1000), () => HapticFeedback.heavyImpact());
      });
    }
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
      widget.onSuccess(false);
    } else {
      // 🔥🔥🔥 RETRY LOGIC IS HERE 🔥🔥🔥
      
      // 1. Alert User (Vibrate + Snackbar)
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ WRONG CODE! RESPINNING..."),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 1),
        )
      );
      
      // 2. Respin the Wheels (Slot Machine Style)
      _playSlotMachineIntro();
      
      // 3. Fetch NEW Challenge (Security: Old nonce expired)
      widget.controller.fetchChallenge();
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
              Positioned.fill(child: Image.asset('assets/z_wheel3.png', fit: BoxFit.contain)),
              ..._buildWheelOverlays(availableWidth, calculatedHeight),
              _buildGlowingButton(availableWidth, calculatedHeight),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildWheelOverlays(double w, double h) {
    List<Widget> overlays = [];
    for (int i = 0; i < wheelCoords.length; i++) {
      double left = wheelCoords[i][0] * (w / imageWidth);
      double top = wheelCoords[i][1] * (h / imageHeight);
      double width = (wheelCoords[i][2] - wheelCoords[i][0]) * (w / imageWidth);
      double height = (wheelCoords[i][3] - wheelCoords[i][1]) * (h / imageHeight);

      overlays.add(Positioned(
        left: left, top: top, width: width, height: height,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification) { if (_scrollControllers[i].position == n.metrics) _onWheelScrollStart(i); }
            else if (n is ScrollUpdateNotification) widget.controller.registerScroll();
            else if (n is ScrollEndNotification) _onWheelScrollEnd(i);
            return false;
          },
          child: _buildInteractiveWheel(i, height),
        ),
      ));
    }
    return overlays;
  }

  Widget _buildInteractiveWheel(int index, double height) {
    bool isActive = _activeWheelIndex == index;
    return GestureDetector(
      onTapDown: (_) => _onWheelScrollStart(index),
      onTapUp: (_) => _onWheelScrollEnd(index),
      onTapCancel: () => _onWheelScrollEnd(index),
      behavior: HitTestBehavior.opaque,
      child: ListWheelScrollView.useDelegate(
        controller: _scrollControllers[index],
        itemExtent: height * 0.4,
        perspective: 0.003,
        diameterRatio: 2.0,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (_) => HapticFeedback.selectionClick(),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, idx) {
            return Center(child: AnimatedBuilder(animation: _opacityAnimations[index], builder: (context, child) {
              return Transform.translate(offset: isActive ? Offset.zero : _textDriftOffsets[index], child: Opacity(opacity: isActive ? 1.0 : _opacityAnimations[index].value, child: Text('${idx % 10}', style: TextStyle(fontSize: height * 0.30, fontWeight: FontWeight.w900, color: isActive ? const Color(0xFFFF5722) : const Color(0xFF263238), shadows: isActive ? [Shadow(color: const Color(0xFFFF5722).withOpacity(0.8), blurRadius: 20)] : [Shadow(offset: const Offset(1, 1), blurRadius: 1, color: Colors.white.withOpacity(0.4)), Shadow(offset: const Offset(-1, -1), blurRadius: 1, color: Colors.black.withOpacity(0.6))]))));
            }));
          },
        ),
      ),
    );
  }

  Widget _buildGlowingButton(double w, double h) {
    double left = buttonCoords[0] * (w / imageWidth);
    double top = buttonCoords[1] * (h / imageHeight);
    double width = (buttonCoords[2] - buttonCoords[0]) * (w / imageWidth);
    double height = (buttonCoords[3] - buttonCoords[1]) * (h / imageHeight);
    return Positioned(left: left, top: top, width: width, height: height, child: GestureDetector(onTap: _onButtonTap, behavior: HitTestBehavior.opaque, child: Stack(children: [Container(color: Colors.transparent), if (_isButtonPressed) IgnorePointer(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFFFF5722).withOpacity(0.6), blurRadius: 30, spreadRadius: 5)])))])));
  }
}
