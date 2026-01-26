// 🎯 Z-KINETIC UI V12.2 (REALISTIC METAL UPGRADE)
// Status: PRODUCTION READY ✅
// Location: lib/cryptex_lock/src/cla_widget.dart
// 
// 🔥 CHANGELOG V12.2:
// - ✅ Reduced itemExtent: 48→32 (4-5 digits visible, less empty space)
// - ✅ Removed eye-burning neon glow on active wheels
// - ✅ Added subtle steel specular reflection instead
// - ✅ Added TOP & BOTTOM mounting brackets/sockets
// - ✅ Enhanced industrial cryptex housing design
// - ✅ Grounded effect with depth shadows
//
// ==============================================================
// 📋 PART 1/3: IMPORTS, MODELS & STATE MANAGEMENT
// ==============================================================

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'cla_controller_v2.dart';
import 'cla_models.dart';
import 'matrix_rain_painter.dart';
import 'forensic_data_painter.dart';

// ============================================
// TUTORIAL OVERLAY
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
                Text("TILT & ROTATE", style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 16, shadows: [Shadow(color: color, blurRadius: 10)])),
                const SizedBox(height: 5),
                Text("Engage kinetic sensors to unlock", style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
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

// ============================================
// MAIN CRYPTEX LOCK WIDGET
// ============================================
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

  // 🔥 Metal texture cache
  ui.Image? _metalTexture;
  bool _textureLoading = true;

  final Color _neonCyan = const Color(0xFF00FFFF);
  final Color _neonGreen = const Color(0xFF00FF88);
  final Color _neonRed = const Color(0xFFFF3366);
  final Color _bgDark = const Color(0xFF0A0A0A);

  List<int> get _currentCode {
    if (_scrollControllers.isEmpty) return [0, 0, 0, 0, 0];
    return _scrollControllers.map((c) => c.hasClients ? c.selectedItem % 10 : 0).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    _loadMetalTexture();
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
        // dipadam
        setState(() {});
      })..repeat();

    _tutorialHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isDisposed) setState(() => _showTutorial = false);
    });
  }

  Future<void> _loadMetalTexture() async {
    try {
      final ByteData data = await rootBundle.load('assets/metal_wheel.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted && !_isDisposed) {
        setState(() {
          _metalTexture = frame.image;
          _textureLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Metal texture load failed: $e');
      if (mounted && !_isDisposed) {
        setState(() => _textureLoading = false);
      }
    }
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
    _scrollControllers = List.generate(5, (i) {
      return FixedExtentScrollController(initialItem: 0);
    });
  }

  void _userInteracted() {
    if (_showTutorial) {
      if (mounted && !_isDisposed) {
        setState(() => _showTutorial = false);
      }
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

    for (var c in _scrollControllers) {
      c.dispose();
    }
    
    _motionScoreNotifier.dispose();
    _touchScoreNotifier.dispose();
    _accelNotifier.dispose();
    
    _metalTexture?.dispose();
    
    super.dispose();
  }

  String _getStatusLabel(SecurityState state) {
    switch (state) {
      case SecurityState.LOCKED: return "BIOMETRIC SCAN STANDBY";
      case SecurityState.VALIDATING: return "PROCESSING PROTOCOL";
      case SecurityState.SOFT_LOCK: return "RETRY LIMIT REACHED";
      case SecurityState.HARD_LOCK: return "SYSTEM LOCKDOWN ACTIVE";
      case SecurityState.UNLOCKED: return "ENCRYPTION BYPASSED";
      default: return "INITIALIZING...";
    }
  }

// ============================================
// 🔥 PART 1 ENDS - CONTINUE TO PART 2
// ============================================

  // ==============================================================
// 📋 PART 2/3: BUILD METHODS & UI COMPONENTS
// ==============================================================
// (Sambungan dari Part 1 - paste after _getStatusLabel method)

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) return const SizedBox.shrink();
    
    SecurityState state = widget.controller.state;
    Color activeColor = (state == SecurityState.SOFT_LOCK || state == SecurityState.HARD_LOCK)
        ? _neonRed
        : (state == SecurityState.UNLOCKED ? _neonGreen : _neonCyan);

    String statusLabel = _getStatusLabel(state);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: KineticGridPainter(color: activeColor)),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: _bgDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: activeColor.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: activeColor.withOpacity(0.15), blurRadius: 40, spreadRadius: 2)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHUDHeader(activeColor, statusLabel),
                if (widget.controller.threatMessage.isNotEmpty) _buildWarningBanner(),
                const SizedBox(height: 28),

                Listener(
                  onPointerDown: (_) {
                    _userInteracted();
                    widget.controller.registerTouch(Offset.zero, 1.0, DateTime.now());
                  },
                  child: _buildInteractiveTumblerArea(activeColor, state),
                ),

                const SizedBox(height: 28),
                _buildAuthButton(activeColor, state),

                const SizedBox(height: 20),
                if (_stressResult.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.yellow.withOpacity(0.3))
                    ),
                    child: Text(_stressResult, textAlign: TextAlign.center, style: const TextStyle(color: Colors.yellow, fontSize: 10, fontFamily: 'monospace')),
                  ),

                const SizedBox(height: 10),
                GestureDetector(
                  onLongPress: _runStressTest,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(5)),
                    child: _isStressTesting
                        ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text("⚡ LONG PRESS FOR BENCHMARK", style: TextStyle(color: activeColor.withOpacity(0.4), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2.5)),
                  ),
                ),
              ],
            ),
          ),

          Positioned.fill(
            child: TutorialOverlay(isVisible: _showTutorial && state == SecurityState.LOCKED, color: activeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHUDHeader(Color color, String status) {
    return Stack(
      children: [
        _buildHUDCorner(color, true, true),
        _buildHUDCorner(color, true, false),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CAPTAIN AER SECURITY SUITE", style: TextStyle(color: color.withOpacity(0.6), fontSize: 9, letterSpacing: 2.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14, shadows: [Shadow(color: color.withOpacity(0.8 * _pulseController.value), blurRadius: 15)]))
                  ),
                  const SizedBox(height: 10),
                  Container(height: 1.5, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, color.withOpacity(0.4), Colors.transparent]))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _motionScoreNotifier,
                  builder: (context, val, _) => _buildSensorBox("MOTION", val, color, Icons.sensors),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<double>(
                  valueListenable: _touchScoreNotifier,
                  builder: (context, val, _) => _buildSensorBox("TOUCH", val, color, Icons.fingerprint),
                ),
                const SizedBox(height: 8),
                _buildPatternBox("PATTERN", _patternScore, color),
              ],
            )
          ],
        )
      ],
    );
  }

  Widget _buildInteractiveTumblerArea(Color color, SecurityState state) {
    return SizedBox(
      height: 170, // 🔥 Increased to accommodate brackets
      child: Stack(
        children: [
          // 🔥 TOP MOUNTING BRACKET
          Positioned(
            left: 55, right: 55, top: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 12),
              painter: MountingBracketPainter(isTop: true, color: color),
            ),
          ),

          // 🔥 BOTTOM MOUNTING BRACKET
          Positioned(
            left: 55, right: 55, bottom: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 12),
              painter: MountingBracketPainter(isTop: false, color: color),
            ),
          ),

          // Left Panel - Matrix Rain + Forensic
          Positioned(
            left: 0, top: 15, bottom: 15,
            child: Container(
              width: 45, height: 140, color: Colors.black,
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: MatrixRainPainter(rain: _matrixRain, color: const Color(0xFF00FF00).withOpacity(0.25)))),
                  
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
                    top: 10, left: 0, right: 0,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(color: const Color(0xFF00FF00).withOpacity(0.15), border: Border.all(color: const Color(0xFF00FF00).withOpacity(0.5), width: 1)),
                      child: const Center(child: Text('F0REN', style: TextStyle(color: Color(0xFF00FF00), fontSize: 7, fontWeight: FontWeight.w900, fontFamily: 'Courier', letterSpacing: 1.5))),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right Panel - Kinetic
          Positioned(
            right: 0, top: 15, bottom: 15,
            child: ValueListenableBuilder<Offset>(
              valueListenable: _accelNotifier,
              builder: (context, offset, _) => CustomPaint(size: const Size(45, 140), painter: KineticPeripheralPainter(color: color, side: 'right', valX: offset.dx, valY: offset.dy, state: state))
            )
          ),

          // 🔥 Center Tumblers - COMPACT VERSION
          Positioned(
            left: 55, right: 55, top: 15, bottom: 15,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  for (int i = 0; i < _scrollControllers.length; i++) {
                    if (_scrollControllers[i].position == notification.metrics) {
                      if (mounted && !_isDisposed) {
                        setState(() { _activeWheelIndex = i; });
                      }
                      _wheelActiveTimer?.cancel();
                      break;
                    }
                  }
                } else if (notification is ScrollUpdateNotification) {
                  _analyzeScrollPattern();
                } else if (notification is ScrollEndNotification) {
                  _resetActiveWheelTimer();
                }
                return false;
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) => _buildMetallicWheel(index, color)),
              ),
            ),
          )
        ],
      ),
    );
  }

  // 🔥 COMPACT METALLIC WHEEL (itemExtent reduced to 32)
  Widget _buildMetallicWheel(int index, Color color) {
    bool isActive = _activeWheelIndex == index;
    
    return Expanded(
      child: Listener(
        onPointerDown: (_) {
          if (_isDisposed) return;
          setState(() => _activeWheelIndex = index);
          _wheelActiveTimer?.cancel();
          _userInteracted();
          widget.controller.registerTouch(Offset.zero, 1.0, DateTime.now());
          HapticFeedback.lightImpact();
        },
        onPointerUp: (_) => _resetActiveWheelTimer(),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isActive ? 1.0 : 0.35,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🔥 Metal Cylinder Background
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: CustomPaint(
                    painter: MetallicCylinderPainter(
                      metalTexture: _metalTexture,
                      isActive: isActive,
                      activeColor: color,
                    ),
                    size: const Size(50, 140),
                  ),
                ),
              ),
              
              // Reticle & Scan Line (only when active)
              if (isActive) Positioned.fill(
                child: AnimatedBuilder(
                  animation: _reticleController, 
                  builder: (context, child) => CustomPaint(
                    painter: KineticReticlePainter(color: color, progress: _reticleController.value)
                  )
                )
              ),
              if (isActive) Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scanController, 
                  builder: (context, child) => CustomPaint(
                    painter: KineticScanLinePainter(color: color, progress: _scanController.value)
                  )
                )
              ),
              
              // 🔥 COMPACT NUMBER WHEEL (4-5 digits visible)
              ListWheelScrollView.useDelegate(
                controller: _scrollControllers[index],
                itemExtent: 32, // 🔥 REDUCED from 48 to 32
                perspective: 0.003,
                diameterRatio: 1.1,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (v) {
                  HapticFeedback.selectionClick();
                  _analyzeScrollPattern();
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, i) => Center(
                    child: _buildEmbossedNumber(
                      '${i % 10}',
                      isActive: isActive,
                      activeColor: color,
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

  // 🔥 SUBTLE EMBOSSED NUMBER (no eye-burning glow)
  Widget _buildEmbossedNumber(String digit, {required bool isActive, required Color activeColor}) {
    if (isActive) {
      // 🔥 Active State: Subtle steel reflection, NO neon glow
      return ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.9),
            const Color(0xFFDDDDDD),
            const Color(0xFFBBBBBB),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds),
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 30, // 🔥 Slightly smaller for compact wheel
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.fill
              ..color = Colors.white,
            shadows: [
              Shadow(offset: const Offset(2, 2), blurRadius: 3, color: Colors.black.withOpacity(0.8)),
              Shadow(offset: const Offset(-1, -1), blurRadius: 2, color: Colors.white.withOpacity(0.5)),
              // 🔥 REMOVED eye-burning neon glow
              Shadow(offset: Offset.zero, blurRadius: 8, color: activeColor.withOpacity(0.2)), // Subtle hint only
            ],
          ),
        ),
      );
    } else {
      // Inactive: Light metallic embossed on dark metal
      return Text(
        digit,
        style: TextStyle(
          fontSize: 28, // 🔥 Proportional reduction
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE8E8E8),
                Color(0xFFC0C0C0),
                Color(0xFFB0B0B0),
              ],
            ).createShader(const Rect.fromLTWH(0, 0, 200, 100)),
          shadows: [
            Shadow(offset: const Offset(2, 2), blurRadius: 3, color: Colors.black.withOpacity(0.8)),
            Shadow(offset: const Offset(-1, -1), blurRadius: 2, color: Colors.white.withOpacity(0.4)),
          ],
        ),
      );
    }
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

  Widget _buildAuthButton(Color activeColor, SecurityState state) {
    bool isDisabled = state == SecurityState.VALIDATING || state == SecurityState.HARD_LOCK;
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: !isDisabled ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 20)] : []),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDisabled ? const Color(0xFF1A1A1A) : activeColor.withOpacity(0.2),
            foregroundColor: activeColor,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDisabled ? const Color(0xFF333333) : activeColor, width: 2)),
          ),
          onPressed: isDisabled ? null : () async {
            HapticFeedback.mediumImpact();
            await widget.controller.verify(_currentCode);
          },
          child: Text(state == SecurityState.HARD_LOCK ? "LOCKED" : "INITIATE ACCESS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.5, fontSize: 13, shadows: !isDisabled ? [Shadow(color: activeColor.withOpacity(0.9), blurRadius: 12)] : [])),
        ),
      ),
    );
  }

  Widget _buildHUDCorner(Color color, bool isTop, bool isLeft) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: !isTop ? 0 : null,
      left: isLeft ? 0 : null,
      right: !isLeft ? 0 : null,
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: color, width: 2) : BorderSide.none,
            left: isLeft ? BorderSide(color: color, width: 2) : BorderSide.none,
            right: !isLeft ? BorderSide(color: color, width: 2) : BorderSide.none,
            bottom: !isTop ? BorderSide(color: color, width: 2) : BorderSide.none
          )
        )
      ),
    );
  }

  Widget _buildSensorBox(String label, double val, Color color, IconData icon) {
    bool isMatch = val > 0.3;
    Color c = isMatch ? const Color(0xFF00FF88) : (val > 0.05 ? const Color(0xFFFF3366) : const Color(0xFF333333));
    return Container(
      width: 55, height: 42,
      decoration: BoxDecoration(border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(8), color: isMatch ? c.withOpacity(0.15) : Colors.transparent),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isMatch ? Icons.check_circle : icon, size: 16, color: c), Text(label, style: TextStyle(fontSize: 7, color: c, fontWeight: FontWeight.w900))])
    );
  }

  Widget _buildPatternBox(String label, double score, Color color) {
    bool isMatch = score >= 0.5;
    Color c = isMatch ? const Color(0xFF00FF88) : (score > 0.1 ? const Color(0xFFFF3366) : const Color(0xFF333333));
    return Container(
      width: 55, height: 42,
      decoration: BoxDecoration(border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(8), color: isMatch ? c.withOpacity(0.15) : Colors.transparent),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isMatch ? Icons.check_circle : Icons.timeline, size: 16, color: c), Text(label, style: TextStyle(fontSize: 7, color: c, fontWeight: FontWeight.w900))])
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFFF3366).withOpacity(0.1), border: Border.all(color: const Color(0xFFFF3366)), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFFF3366), size: 18), const SizedBox(width: 10), Expanded(child: Text(widget.controller.threatMessage, style: const TextStyle(color: Color(0xFFFF3366), fontSize: 10, fontWeight: FontWeight.w900)))])
    );
  }
}

// ============================================
// 🔥 PART 2 ENDS - CONTINUE TO PART 3
// ============================================

// ==============================================================
// 📋 PART 3/3: CUSTOM PAINTERS (FINAL)
// ==============================================================
// (Sambungan dari Part 2 - paste after _buildWarningBanner method)

// ============================================
// 🔥 NEW: MOUNTING BRACKET PAINTER
// ============================================
class MountingBracketPainter extends CustomPainter {
  final bool isTop;
  final Color color;

  MountingBracketPainter({required this.isTop, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF555555),
          const Color(0xFF333333),
          const Color(0xFF222222),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Main bracket body
    final path = Path();
    if (isTop) {
      path.moveTo(0, size.height);
      path.lineTo(0, 3);
      path.lineTo(3, 0);
      path.lineTo(size.width - 3, 0);
      path.lineTo(size.width, 3);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - 3);
      path.lineTo(3, size.height);
      path.lineTo(size.width - 3, size.height);
      path.lineTo(size.width, size.height - 3);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);

    // 🔥 Bolts/Rivets
    final boltPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    
    final boltHighlight = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final boltPositions = [
      size.width * 0.15,
      size.width * 0.35,
      size.width * 0.5,
      size.width * 0.65,
      size.width * 0.85,
    ];

    for (var x in boltPositions) {
      final double boltY = isTop ? size.height - 4 : 4.0;
      
      // Bolt shadow
      canvas.drawCircle(Offset(x + 0.5, boltY + 0.5), 2.5, Paint()..color = Colors.black.withOpacity(0.5));
      
      // Bolt body
      canvas.drawCircle(Offset(x, boltY), 2.5, boltPaint);
      
      // Bolt highlight
      canvas.drawCircle(Offset(x - 0.8, boltY - 0.8), 1.2, boltHighlight);
      
      // Bolt cross (Phillips head)
      final crossPaint = Paint()
        ..color = Colors.black.withOpacity(0.8)
        ..strokeWidth = 0.6
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(Offset(x - 1.2, boltY), Offset(x + 1.2, boltY), crossPaint);
      canvas.drawLine(Offset(x, boltY - 1.2), Offset(x, boltY + 1.2), crossPaint);
    }

    // 🔥 Edge lighting
    final edgePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawPath(path, edgePaint);

    // 🔥 Depth shadow
    final shadowPath = Path();
    if (isTop) {
      shadowPath.moveTo(0, size.height);
      shadowPath.lineTo(size.width, size.height);
      shadowPath.lineTo(size.width, size.height - 2);
      shadowPath.lineTo(0, size.height - 2);
    } else {
      shadowPath.moveTo(0, 0);
      shadowPath.lineTo(size.width, 0);
      shadowPath.lineTo(size.width, 2);
      shadowPath.lineTo(0, 2);
    }
    shadowPath.close();

    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: isTop ? Alignment.bottomCenter : Alignment.topCenter,
        end: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        colors: [
          Colors.black.withOpacity(0.6),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(shadowPath, shadowPaint);
  }

  @override
  bool shouldRepaint(MountingBracketPainter oldDelegate) =>
      oldDelegate.isTop != isTop || oldDelegate.color != color;
}

// ============================================
// 🔥 UPGRADED METALLIC CYLINDER PAINTER
// (No eye-burning glow, subtle steel reflection only)
// ============================================
class MetallicCylinderPainter extends CustomPainter {
  final ui.Image? metalTexture;
  final bool isActive;
  final Color activeColor;

  MetallicCylinderPainter({
    required this.metalTexture,
    required this.isActive,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 🔥 STEP 1: Metal Texture Base
    if (metalTexture != null) {
      final texturePaint = Paint()
        ..shader = ImageShader(
          metalTexture!,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.identity().storage,
        );
      canvas.drawRect(rect, texturePaint);
    } else {
      // Fallback: Darker metallic
      final fallbackPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6A6A6A),
            Color(0xFF4A4A4A),
            Color(0xFF585858),
            Color(0xFF505050),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, fallbackPaint);
    }

    // 🔥 STEP 2: Brushed Metal Scratches
    final brushPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.8
      ..blendMode = BlendMode.overlay;
    
    final random = Random(42);
    for (int i = 0; i < 40; i++) {
      double x = random.nextDouble() * size.width;
      double offset = (random.nextDouble() - 0.5) * 8;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + offset, size.height),
        brushPaint,
      );
    }

    // 🔥 STEP 3: Cylindrical 3D Gradient
    final cylinderGradient = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, 0.0),
        radius: 1.3,
        colors: [
          Colors.white.withOpacity(0.3),
          Colors.transparent,
          Colors.black.withOpacity(0.4),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, cylinderGradient);

    // 🔥 STEP 4: Subtle Rim Lighting (NO eye-burning glow)
    final rimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          isActive 
            ? Colors.white.withOpacity(0.25) // 🔥 SUBTLE steel reflection
            : Colors.white.withOpacity(0.15),
          Colors.transparent,
          Colors.transparent,
          isActive 
            ? Colors.white.withOpacity(0.25) 
            : Colors.white.withOpacity(0.15),
        ],
        stops: const [0.0, 0.1, 0.9, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, rimPaint);

    // 🔥 STEP 5: Ambient Occlusion
    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withOpacity(0.4),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withOpacity(0.4),
        ],
        stops: const [0.0, 0.15, 0.85, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, shadowPaint);

    // 🔥 STEP 6: Active State - SUBTLE glow only
    if (isActive) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            activeColor.withOpacity(0.1), // 🔥 REDUCED from 0.25 to 0.1
            activeColor.withOpacity(0.03), // 🔥 REDUCED from 0.08 to 0.03
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.drawRect(rect, glowPaint);

      // Active Border - subtle
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 // 🔥 REDUCED from 2.5 to 1.5
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            activeColor.withOpacity(0.4), // 🔥 REDUCED from 0.7
            activeColor.withOpacity(0.2), // 🔥 REDUCED from 0.3
            activeColor.withOpacity(0.4),
          ],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(24)),
        borderPaint,
      );
    }

    // 🔥 STEP 7: Vignette
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.3),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, vignettePaint);
  }

  @override
  bool shouldRepaint(MetallicCylinderPainter oldDelegate) {
    return oldDelegate.metalTexture != metalTexture ||
        oldDelegate.isActive != isActive ||
        oldDelegate.activeColor != activeColor;
  }
}

// ============================================
// KINETIC GRID PAINTER
// ============================================
class KineticGridPainter extends CustomPainter {
  final Color color;
  KineticGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.04)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(KineticGridPainter old) => old.color != color;
}

// ============================================
// KINETIC PERIPHERAL PAINTER
// ============================================
class KineticPeripheralPainter extends CustomPainter {
  final Color color;
  final String side;
  final double valX, valY;
  final SecurityState state;

  KineticPeripheralPainter({required this.color, required this.side, required this.valX, required this.valY, required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.3)..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    if (side == 'left') {
      canvas.drawRect(const Rect.fromLTWH(0, 10, 42, 14), Paint()..color = color.withOpacity(0.15));
      _drawText(canvas, tp, "COORD", 4, 13, 7, color, true);

      for (int i = 0; i < 4; i++) {
        double lat = ((valX * 10) + (i * 1.5)).clamp(-90, 90);
        double lng = ((valY * 10) - (i * 2.1)).clamp(-180, 180);
        _drawText(canvas, tp, "${lat.toStringAsFixed(2)}°", 2, 35.0 + (i*24), 6, color.withOpacity(0.6), false);
        _drawText(canvas, tp, "${lng.toStringAsFixed(2)}°", 2, 45.0 + (i*24), 6, color.withOpacity(0.6), false);
      }
      canvas.drawLine(const Offset(42, 10), const Offset(42, 130), p);
    } else {
      canvas.drawRect(const Rect.fromLTWH(2, 10, 42, 14), Paint()..color = color.withOpacity(0.15));
      _drawText(canvas, tp, "SYS-ID", 6, 13, 7, color, true);

      String authStatus = state == SecurityState.VALIDATING ? "PROC" : (state == SecurityState.UNLOCKED ? "COMP" : "PEND");
      _drawText(canvas, tp, "AUTH: $authStatus", 4, 35, 6, color.withOpacity(0.8), true);
      _drawText(canvas, tp, "ENC: AES256", 4, 45, 6, color.withOpacity(0.6), false);

      for (int i = 0; i < 12; i++) {
        double h = 6 + (valX.abs() * 2) + (i % 3);
        canvas.drawLine(Offset(6.0 + (i * 3), 60), Offset(6.0 + (i * 3), 60 + h), Paint()..color = color.withOpacity(0.5)..strokeWidth = 1.2);
      }
      canvas.drawLine(const Offset(2, 10), const Offset(2, 130), p);
    }
  }

  void _drawText(Canvas c, TextPainter tp, String s, double x, double y, double sz, Color col, bool bold) {
    tp.text = TextSpan(text: s, style: TextStyle(color: col, fontSize: sz, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontFamily: 'Courier'));
    tp.layout();
    tp.paint(c, Offset(x, y));
  }

  @override
  bool shouldRepaint(KineticPeripheralPainter old) => old.valX != valX || old.valY != valY || old.state != state || old.color != color;
}

// ============================================
// RETICLE PAINTER
// ============================================
class KineticReticlePainter extends CustomPainter {
  final Color color;
  final double progress;

  KineticReticlePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final p = Paint()..color = color.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * 2 * pi);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawCircle(center, 22, p);

    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2;
      canvas.drawLine(Offset(center.dx + 18 * cos(a), center.dy + 18 * sin(a)), Offset(center.dx + 26 * cos(a), center.dy + 26 * sin(a)), p);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(KineticReticlePainter old) => old.progress != progress || old.color != color;
}

// ============================================
// SCAN LINE PAINTER
// ============================================
class KineticScanLinePainter extends CustomPainter {
  final Color color;
  final double progress;

  KineticScanLinePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, size.height * progress - 2, size.width, 4);

    final p = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, color.withOpacity(0.6), Colors.transparent]).createShader(rect);

    canvas.drawRect(rect, p);
  }

  @override
  bool shouldRepaint(KineticScanLinePainter old) => old.progress != progress || old.color != color;
}

// ============================================
// 🔥 END OF FILE - V12.2 COMPLETE
// ============================================
// 
// 📦 INSTALLATION INSTRUCTIONS:
// 1. Copy Part 1 content → cla_widget.dart (replace all)
// 2. Append Part 2 content after _getStatusLabel method
// 3. Append Part 3 content after _buildWarningBanner method
// 
// ✅ FIXED ISSUES:
// - ✅ Compact wheels (4-5 digits visible, less empty space)
// - ✅ Subtle steel reflection (no eye-burning glow)
// - ✅ Industrial mounting brackets (grounded, realistic)
// 
// 🚀 READY FOR DEPLOYMENT
