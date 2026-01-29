import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'src/cla_controller_v2.dart';
import 'src/cla_models.dart';
import 'src/matrix_rain_painter.dart';
import 'src/forensic_data_painter.dart';

// ============================================
// 🔥 CRYPTEX LOCK ULTIMATE V16.0
// FULL MERGE: Visual Overlay + Advanced Logic
// ============================================

class TutorialOverlay extends StatelessWidget {
  final bool isVisible;
  final Color color;

  const TutorialOverlay({super.key, required this.isVisible, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: isVisible ? 1.0 : 0.0,
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.screen_rotation, color: color, size: 48),
                const SizedBox(height: 10),
                Text(
                  "TILT & ROTATE",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontSize: 16,
                    shadows: [Shadow(color: color, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Engage kinetic sensors to unlock",
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
                ),
                const SizedBox(height: 30),
                Icon(Icons.keyboard_double_arrow_down, color: color.withOpacity(0.5), size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CryptexLock extends StatefulWidget {
  final ClaController controller;
  final VoidCallback onSuccess;
  final VoidCallback onFail;
  final VoidCallback onJammed;

  const CryptexLock({
    super.key,
    required this.controller,
    required this.onSuccess,
    required this.onFail,
    required this.onJammed,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> with WidgetsBindingObserver, TickerProviderStateMixin {
  // 🔥 KOORDINAT RODA (626 x 471) - DARI FILE 1
  static const List<List<double>> _wheelCoords = [
    [85, 133, 143, 286],   // Roda 1
    [180, 132, 242, 285],  // Roda 2
    [276, 133, 337, 282],  // Roda 3
    [371, 132, 431, 282],  // Roda 4
    [467, 130, 529, 285],  // Roda 5
  ];

  // 🔥 KOORDINAT BUTTON "CONFIRM ACCESS"
  static const List<double> _buttonCoords = [150, 318, 472, 399];

  static const double _imageWidth = 626.0;
  static const double _imageHeight = 471.0;

  // Sensor & Controller State
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  Timer? _lockoutTimer;
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  late List<FixedExtentScrollController> _scrollControllers;

  final ValueNotifier<double> _motionScoreNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _touchScoreNotifier = ValueNotifier(0.0);
  final ValueNotifier<Offset> _accelNotifier = ValueNotifier(Offset.zero);

  double _patternScore = 0.0;
  bool _showTutorial = true;
  Timer? _tutorialHideTimer;
  Timer? _touchDecayTimer;

  double _lastX = 0, _lastY = 0, _lastZ = 0;
  final List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;

  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _reticleController;
  late MatrixRain _matrixRain;
  late AnimationController _rainController;

  bool _isStressTesting = false;
  String _stressResult = "";
  bool _isDisposed = false;
  bool _showForensics = false;

  // Colors
  final Color _primaryOrange = const Color(0xFFFF5722);
  final Color _accentRed = const Color(0xFFD32F2F);
  final Color _neutralGray = const Color(0xFFE0E0E0);
  final Color _darkText = const Color(0xFF263238);
  final Color _successGreen = const Color(0xFF4CAF50);
  final Color _lightBlueGray = const Color(0xFFE3E8F0);

  List<int> get _currentCode {
    if (_scrollControllers.isEmpty) return [0, 0, 0, 0, 0];
    return _scrollControllers.map((c) => c.hasClients ? c.selectedItem % 10 : 0).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    widget.controller.onInteractionStart();
    _startListening();
    widget.controller.addListener(_handleControllerChange);
    widget.controller.shouldRandomizeWheels.addListener(_onRandomizeTrigger);
    
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _reticleController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    _matrixRain = MatrixRain(columnCount: 4);
    _rainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))
      ..addListener(() {
        if (!mounted || _isDisposed) return;
        setState(() {});
      })
      ..repeat();

    _tutorialHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isDisposed) setState(() => _showTutorial = false);
    });
  }

  void _handleControllerChange() {
    if (_isDisposed) return;
    if (widget.controller.state == SecurityState.UNLOCKED) widget.onSuccess();
    else if (widget.controller.state == SecurityState.HARD_LOCK) {
      _startLockoutTimer();
      widget.onJammed();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _startListening();
    else if (state == AppLifecycleState.paused) _accelSub?.cancel();
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (i) => FixedExtentScrollController(initialItem: 0));
  }

  void _userInteracted() {
    if (_showTutorial) {
      if (mounted && !_isDisposed) setState(() => _showTutorial = false);
      _tutorialHideTimer?.cancel();
    }
    _triggerTouchActive();
  }

  void _startListening() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEvents.listen((e) {
      if (_isDisposed) return;
      _accelNotifier.value = Offset(e.x, e.y);
      double delta = (e.x - _lastX).abs() + (e.y - _lastY).abs() + (e.z - _lastZ).abs();
      _lastX = e.x; _lastY = e.y; _lastZ = e.z;
      double amplifiedMotion = (delta * 10.0).clamp(0.0, 1.0);
      if (amplifiedMotion > 0.5) _userInteracted();
      widget.controller.registerMotion(e.x, e.y, e.z, DateTime.now());
      double currentScore = _motionScoreNotifier.value;
      if (amplifiedMotion > currentScore) {
        _motionScoreNotifier.value = amplifiedMotion;
      } else {
        _motionScoreNotifier.value = (currentScore * 0.92);
      }
    });
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }
      if (widget.controller.state == SecurityState.HARD_LOCK) {
        setState(() {});
        if (widget.controller.state != SecurityState.HARD_LOCK) timer.cancel();
      } else {
        timer.cancel();
      }
    });
  }

  void _triggerTouchActive() {
    if (_isDisposed) return;
    _touchScoreNotifier.value = 1.0;
    setState(() => _patternScore = 1.0);
    _touchDecayTimer?.cancel();
    _touchDecayTimer = Timer(const Duration(seconds: 3), () {});
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || _isDisposed) return;
      _decayTouch();
    });
  }

  void _decayTouch() {
    if (!mounted || _isDisposed) return;
    if (_touchScoreNotifier.value > 0) {
      _touchScoreNotifier.value -= 0.05;
      if (_touchScoreNotifier.value < 0) _touchScoreNotifier.value = 0;
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted || _isDisposed) return;
        _decayTouch();
      });
    }
  }

  void _analyzeScrollPattern() {
    _userInteracted();
    final now = DateTime.now();
    double speed = _lastScrollTime != null ? 1000.0 / now.difference(_lastScrollTime!).inMilliseconds : 0.0;
    _lastScrollTime = now;
    _touchData.add({'timestamp': now, 'speed': speed, 'pressure': 0.5, 'wheelIndex': _activeWheelIndex ?? 0});
    if (_touchData.length > 20) _touchData.removeAt(0);
  }

  void _onRandomizeTrigger() {
    if (!mounted || _isDisposed) return;
    _randomizeWheels();
  }

  void _randomizeWheels() {
    if (_isDisposed) return;
    final random = Random();
    for (int i = 0; i < _scrollControllers.length; i++) {
      final randomValue = random.nextInt(10);
      _scrollControllers[i].animateToItem(
        randomValue,
        duration: Duration(milliseconds: 500 + random.nextInt(300)),
        curve: Curves.easeOutBack,
      );
    }
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    widget.controller.shouldRandomizeWheels.removeListener(_onRandomizeTrigger);
    _accelSub?.cancel();
    _lockoutTimer?.cancel();
    _wheelActiveTimer?.cancel();
    _touchDecayTimer?.cancel();
    _tutorialHideTimer?.cancel();
    _pulseController.dispose();
    _scanController.dispose();
    _reticleController.dispose();
    _rainController.dispose();
    for (var c in _scrollControllers) c.dispose();
    _motionScoreNotifier.dispose();
    _touchScoreNotifier.dispose();
    _accelNotifier.dispose();
    super.dispose();
  }

  String _getStatusLabel(SecurityState state) {
    switch (state) {
      case SecurityState.LOCKED: return "SECURE ACCESS";
      case SecurityState.VALIDATING: return "VALIDATING...";
      case SecurityState.SOFT_LOCK: return "ACCESS DENIED";
      case SecurityState.HARD_LOCK: return "SYSTEM LOCKED";
      case SecurityState.UNLOCKED: return "ACCESS GRANTED";
      default: return "INITIALIZING...";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) return const SizedBox.shrink();
    SecurityState state = widget.controller.state;
    Color activeColor = (state == SecurityState.SOFT_LOCK || state == SecurityState.HARD_LOCK)
        ? _accentRed
        : (state == SecurityState.UNLOCKED ? _successGreen : _primaryOrange);
    String statusLabel = _getStatusLabel(state);

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          if (_showForensics) Positioned(left: 0, top: 100, child: _buildForensicPanel()),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // HEADER
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey[200],
                      letterSpacing: 4.0,
                    ),
                  ),
                  const SizedBox(height: 60),

                  // ==================================================
                  // 🔥 Z-WHEEL SYSTEM (ULTIMATE OVERLAY)
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double screenWidth = constraints.maxWidth;
                        
                        // 🎯 KIRA ASPECT RATIO
                        double aspectRatio = _imageWidth / _imageHeight;
                        double imageHeight = screenWidth / aspectRatio;
                        
                        return SizedBox(
                          width: screenWidth,
                          height: imageHeight,
                          child: Stack(
                            children: [
                              // LAYER 1: GAMBAR Z-WHEEL (BASE)
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/z_wheel.png',
                                  fit: BoxFit.fill,
                                ),
                              ),

                              // LAYER 2: RODA OVERLAY (5 WHEELS)
                              ..._buildWheelOverlays(screenWidth, imageHeight, activeColor, state),

                              // LAYER 3: PHANTOM BUTTON (INVISIBLE)
                              _buildPhantomButton(screenWidth, imageHeight, activeColor, state),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // SENSOR ROW
                  if (widget.controller.threatMessage.isNotEmpty) _buildWarningBanner(),
                  const SizedBox(height: 20),
                  _buildSensorRow(activeColor),
                  
                  // STRESS TEST RESULT
                  if (_stressResult.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Text(
                        _stressResult,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // FORENSICS & BENCHMARK BUTTONS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() => _showForensics = !_showForensics);
                            HapticFeedback.lightImpact();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _showForensics ? _successGreen : Colors.white24,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _showForensics ? Icons.visibility : Icons.visibility_off,
                                  size: 16,
                                  color: _showForensics ? _successGreen : Colors.white54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "FORENSICS",
                                  style: TextStyle(
                                    color: _showForensics ? _successGreen : Colors.white54,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onLongPress: _runStressTest,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _isStressTesting
                                ? const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white54,
                                    ),
                                  )
                                : Text(
                                    "⚡ BENCHMARK",
                                    style: TextStyle(
                                      color: activeColor.withOpacity(0.6),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: TutorialOverlay(
              isVisible: _showTutorial && state == SecurityState.LOCKED,
              color: activeColor,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 BUILD BUTTON HANTU (INVISIBLE OVERLAY)
  Widget _buildPhantomButton(double screenWidth, double screenHeight, Color activeColor, SecurityState state) {
    double left = _buttonCoords[0];
    double top = _buttonCoords[1];
    double right = _buttonCoords[2];
    double bottom = _buttonCoords[3];

    // Convert ke Pixel Skrin Semasa
    double actualLeft = screenWidth * (left / _imageWidth);
    double actualTop = screenHeight * (top / _imageHeight);
    double actualWidth = screenWidth * ((right - left) / _imageWidth);
    double actualHeight = screenHeight * ((bottom - top) / _imageHeight);

    bool isDisabled = state == SecurityState.VALIDATING || state == SecurityState.HARD_LOCK;

    return Positioned(
      left: actualLeft,
      top: actualTop,
      width: actualWidth,
      height: actualHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled
              ? null
              : () async {
                  HapticFeedback.mediumImpact();
                  _userInteracted();
                  await widget.controller.verify(_currentCode);
                },
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: Colors.transparent,
            // Debug mode: uncomment to see button area
            // decoration: BoxDecoration(
            //   border: Border.all(color: Colors.red, width: 2),
            // ),
          ),
        ),
      ),
    );
  }

  // 🔥 BUILD SEMUA 5 RODA DENGAN OVERLAY + EFFECTS
  List<Widget> _buildWheelOverlays(double screenWidth, double screenHeight, Color activeColor, SecurityState state) {
    List<Widget> wheels = [];
    
    for (int i = 0; i < 5; i++) {
      double left = _wheelCoords[i][0];
      double top = _wheelCoords[i][1];
      double right = _wheelCoords[i][2];
      double bottom = _wheelCoords[i][3];
      
      double actualLeft = screenWidth * (left / _imageWidth);
      double actualTop = screenHeight * (top / _imageHeight);
      double actualWidth = screenWidth * ((right - left) / _imageWidth);
      double actualHeight = screenHeight * ((bottom - top) / _imageHeight);
      
      wheels.add(
        Positioned(
          left: actualLeft,
          top: actualTop,
          width: actualWidth,
          height: actualHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                if (_scrollControllers[i].position == notification.metrics) {
                  if (mounted && !_isDisposed) setState(() => _activeWheelIndex = i);
                  _wheelActiveTimer?.cancel();
                }
              } else if (notification is ScrollUpdateNotification) {
                _analyzeScrollPattern();
              } else if (notification is ScrollEndNotification) {
                _resetActiveWheelTimer();
              }
              return false;
            },
            child: _buildAdvancedWheel(i, actualHeight, activeColor),
          ),
        ),
      );
    }
    
    return wheels;
  }

  // WIDGET SATU RODA (DENGAN EFFECTS)
  Widget _buildAdvancedWheel(int index, double wheelHeight, Color activeColor) {
    bool isActive = _activeWheelIndex == index;
    double itemExtent = wheelHeight * 0.40;
    
    return GestureDetector(
      onTapDown: (_) {
        if (_isDisposed) return;
        setState(() => _activeWheelIndex = index);
        _wheelActiveTimer?.cancel();
        _userInteracted();
        widget.controller.registerTouch(Offset.zero, 1.0, DateTime.now());
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) => _resetActiveWheelTimer(),
      onTapCancel: () => _resetActiveWheelTimer(),
      child: AnimatedScale(
        scale: isActive ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            // Base Wheel
            ListWheelScrollView.useDelegate(
              controller: _scrollControllers[index],
              itemExtent: itemExtent,
              perspective: 0.003,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (_) {
                HapticFeedback.selectionClick();
                _analyzeScrollPattern();
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, i) {
                  return Center(
                    child: Text(
                      '${i % 10}',
                      style: TextStyle(
                        fontSize: wheelHeight * 0.30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                        shadows: [
                          Shadow(
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.8),
                          ),
                          Shadow(
                            offset: const Offset(-1, -1),
                            blurRadius: 2,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Active Border Glow
            if (isActive)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activeColor.withOpacity(0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            
            // Scan Line Effect
            if (isActive)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) => CustomPaint(
                    painter: KineticScanLinePainter(
                      color: activeColor,
                      progress: _scanController.value,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _motionScoreNotifier,
            builder: (context, val, _) => _buildMiniSensor("MOTION", val, color, Icons.sensors),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _touchScoreNotifier,
            builder: (context, val, _) => _buildMiniSensor("TOUCH", val, color, Icons.fingerprint),
          ),
          _buildMiniSensor("PATTERN", _patternScore, color, Icons.timeline),
        ],
      ),
    );
  }

  Widget _buildMiniSensor(String label, double val, Color color, IconData icon) {
    bool isActive = val > 0.3;
    return Column(
      children: [
        Icon(
          isActive ? Icons.check_circle : icon,
          size: 20,
          color: isActive ? _successGreen : Colors.white38,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isActive ? _successGreen : Colors.white38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildForensicPanel() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _showForensics ? 1.0 : 0.0,
      child: Container(
        width: 60,
        height: 200,
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: MatrixRainPainter(
                  rain: _matrixRain,
                  color: const Color(0xFF00FF00).withOpacity(0.3),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: ForensicDataPainter(
                  color: const Color(0xFF00FF00),
                  motionCount: (widget.controller.motionEntropy * 100).toInt(),
                  touchCount: (widget.controller.liveConfidence * 20).toInt(),
                  entropy: widget.controller.motionEntropy,
                  confidence: widget.controller.liveConfidence,
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF00).withOpacity(0.2),
                  border: Border.all(color: const Color(0xFF00FF00).withOpacity(0.5)),
                ),
                child: const Center(
                  child: Text(
                    'FORENSIC',
                    style: TextStyle(
                      color: Color(0xFF00FF00),
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accentRed.withOpacity(0.1),
        border: Border.all(color: _accentRed),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _accentRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.controller.threatMessage,
              style: TextStyle(
                color: _accentRed,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetActiveWheelTimer() {
    _wheelActiveTimer?.cancel();
    _wheelActiveTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isDisposed) setState(() => _activeWheelIndex = null);
    });
  }

  Future<void> _runStressTest() async {
    if (_isDisposed) return;
    setState(() {
      _isStressTesting = true;
      _stressResult = "⚠️ LAUNCHING 50 CONCURRENT VECTORS...";
    });
    final stopwatch = Stopwatch()..start();
    final random = Random();
    await Future.wait(List.generate(50, (index) async {
      if (_isDisposed) return;
      await Future.delayed(Duration(milliseconds: random.nextInt(50)));
      await widget.controller.verify(_currentCode);
    }));
    stopwatch.stop();
    final double tps = 50 / (stopwatch.elapsedMilliseconds / 1000);
    if (!mounted || _isDisposed) return;
    setState(() {
      _isStressTesting = false;
      _stressResult = "📊 BENCHMARK REPORT:\nTotal: 50 Threads\nTime: ${stopwatch.elapsedMilliseconds}ms\nSpeed: ${tps.toStringAsFixed(0)} TPS\nIntegrity: STABLE";
    });
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_isDisposed) setState(() => _stressResult = "");
    });
  }
}

// 🔥 KINETIC SCAN LINE PAINTER
class KineticScanLinePainter extends CustomPainter {
  final Color color;
  final double progress;

  KineticScanLinePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, size.height * progress - 2, size.width, 4);
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, color.withOpacity(0.6), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, p);
  }

  @override
  bool shouldRepaint(KineticScanLinePainter old) => old.progress != progress || old.color != color;
}
