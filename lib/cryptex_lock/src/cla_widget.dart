// cryptex_lock_aer
// 🚀 FULL SCI-FI GAME UI REDESIGN - FINAL FIX
// Fixed: Class renamed to 'CryptexLock' to match main.dart

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

// Pastikan import ini wujud dalam projek Kapten
import 'cla_controller.dart';
import 'cla_models.dart';

// ============================================
// 1. UTILITY & MODELS
// ============================================

class MLPatternAnalyzer {
  static double analyzePattern(List<Map<String, dynamic>> touchData) {
    if (touchData.length < 5) return 0.0;
    List<double> features = [];
    List<int> intervals = [];
    for (int i = 1; i < touchData.length; i++) {
      intervals.add(touchData[i]['timestamp'].difference(touchData[i - 1]['timestamp']).inMilliseconds);
    }
    double timingVariance = _calculateVariance(intervals.map((e) => e.toDouble()).toList());
    features.add(timingVariance / 1000.0);
    
    if (touchData[0].containsKey('pressure')) {
      List<double> pressures = touchData.map((e) => e['pressure'] as double).toList();
      features.add(_calculateVariance(pressures));
    } else {
      features.add(0.5);
    }
    
    if (touchData[0].containsKey('speed')) {
      List<double> speeds = touchData.map((e) => e['speed'] as double).toList();
      features.add(_calculateVariance(speeds));
    } else {
      features.add(0.5);
    }
    
    features.add(_detectTremor(touchData));
    double humanScore = features[0] * 0.3 + features[1] * 0.2 + features[2] * 0.2 + features[3] * 0.3;
    return humanScore.clamp(0.0, 1.0);
  }

  static double _calculateVariance(List<double> data) {
    if (data.isEmpty) return 0.0;
    double mean = data.reduce((a, b) => a + b) / data.length;
    double sumSquaredDiff = data.map((x) => pow(x - mean, 2).toDouble()).reduce((a, b) => a + b);
    return sumSquaredDiff / data.length;
  }

  static double _detectTremor(List<Map<String, dynamic>> touchData) {
    if (touchData.length < 10) return 0.5;
    int microMovements = 0;
    for (int i = 1; i < touchData.length; i++) {
      int timeDiff = touchData[i]['timestamp'].difference(touchData[i - 1]['timestamp']).inMilliseconds;
      if (timeDiff > 80 && timeDiff < 125) microMovements++;
    }
    return (microMovements / touchData.length).clamp(0.0, 1.0);
  }
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double size;

  Particle()
      : x = Random().nextDouble() * 400,
        y = Random().nextDouble() * 800,
        vx = (Random().nextDouble() - 0.5) * 0.5,
        vy = Random().nextDouble() * 0.3 + 0.1,
        life = 1.0,
        size = Random().nextDouble() * 2 + 1;

  void update() {
    x += vx;
    y += vy;
    life -= 0.01;

    if (x < 0 || x > 400) vx *= -1;
    if (y > 800) {
      y = 0;
      life = 1.0;
    }
  }
}

// ============================================
// 2. MAIN WIDGET
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

class _CryptexLockState extends State<CryptexLock> with TickerProviderStateMixin, WidgetsBindingObserver {
  // Original controllers
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  Timer? _lockoutTimer;
  Timer? _screenshotWatchdog;
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  late List<FixedExtentScrollController> _scrollControllers;

  double _patternScore = 0.0;
  List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;
  bool _suspiciousRootBypass = false;

  // 🎮 NEW: Advanced animation controllers
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _glitchController;
  late AnimationController _particleController;
  late AnimationController _hexagonController;

  // 🎮 Particle system
  List<Particle> _particles = [];
  Timer? _particleTimer;

  // 🎮 Colors - Full spectrum
  final Color _cyan = const Color(0xFF00FFFF);
  final Color _blue = const Color(0xFF0080FF);
  final Color _purple = const Color(0xFF8000FF);
  final Color _orange = const Color(0xFFFF6B00);
  final Color _red = const Color(0xFFFF0040);
  final Color _green = const Color(0xFF00FF88);
  final Color _yellow = const Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    _startListening();
    _enableAntiScreenshot();
    _startScreenshotWatchdog();
    _checkRootBypass();
    widget.controller.addListener(_handleControllerChange);

    // 🎮 Initialize all animations
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _hexagonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 🎮 Spawn particles
    _particleTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_particles.length < 50) {
        if (mounted) {
          setState(() {
            _particles.add(Particle());
          });
        }
      }
      _particles.removeWhere((p) => p.life <= 0);
    });
  }

  void _enableAntiScreenshot() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      const platform = MethodChannel('com.cryptex/security');
      platform.invokeMethod('enableScreenshotProtection');
    } catch (e) {
      debugPrint("Anti-Screenshot Init Error: $e");
    }
  }

  void _startScreenshotWatchdog() {
    _screenshotWatchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      _detectScreenshotAttempt();
    });
  }

  void _detectScreenshotAttempt() async {
    try {
      const platform = MethodChannel('com.cryptex/security');
      final bool detected = await platform.invokeMethod('checkScreenshot');
      if (detected && mounted) debugPrint("⚠️ Screenshot detected");
    } catch (e) {}
  }

  void _checkRootBypass() async {
    try {
      const platform = MethodChannel('com.cryptex/security');
      final bool detected = await platform.invokeMethod('detectRootBypass', {
        'packages': ['com.topjohnwu.magisk', 'eu.chainfire.supersu'],
        'paths': ['/system/xbin/su', '/system/bin/su'],
      });
      if (detected && mounted) setState(() => _suspiciousRootBypass = true);
    } catch (e) {}
  }

  void _handleControllerChange() {
    if (widget.controller.state == SecurityState.UNLOCKED) {
      widget.onSuccess();
    } else if (widget.controller.state == SecurityState.HARD_LOCK) {
      widget.onJammed();
      _startLockoutTimer();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _accelSub?.cancel();
      _lockoutTimer?.cancel();
      _screenshotWatchdog?.cancel();
      _wheelActiveTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startListening();
      if (widget.controller.state == SecurityState.HARD_LOCK) _startLockoutTimer();
      _startScreenshotWatchdog();
    }
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (i) {
      return FixedExtentScrollController(initialItem: widget.controller.getInitialValue(i));
    });
  }

  void _startListening() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEvents.listen((e) {
      double mag = e.x.abs() + e.y.abs() + e.z.abs();
      widget.controller.registerShake(mag, e.x, e.y, e.z);
    });
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.controller.state == SecurityState.HARD_LOCK) {
        setState(() {});
        if (widget.controller.remainingLockoutSeconds <= 0) timer.cancel();
      } else {
        timer.cancel();
      }
    });
  }

  void _analyzeScrollPattern() {
    final now = DateTime.now();
    double speed = 0.0;
    if (_lastScrollTime != null) {
      speed = 1000.0 / now.difference(_lastScrollTime!).inMilliseconds.toDouble();
    }
    _lastScrollTime = now;

    _touchData.add({
      'timestamp': now,
      'speed': speed,
      'pressure': 0.3 + Random().nextDouble() * 0.4,
      'wheelIndex': _activeWheelIndex ?? 0,
    });

    if (_touchData.length > 20) _touchData.removeAt(0);

    if (_touchData.length >= 5) {
      double mlScore = MLPatternAnalyzer.analyzePattern(_touchData);
      _patternScore = mlScore < 0.3 ? mlScore : (mlScore < 0.5 ? 0.5 : mlScore);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    _accelSub?.cancel();
    _lockoutTimer?.cancel();
    _screenshotWatchdog?.cancel();
    _wheelActiveTimer?.cancel();
    _particleTimer?.cancel();
    _rotationController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    _glitchController.dispose();
    _particleController.dispose();
    _hexagonController.dispose();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainUI();
  }

  Widget _buildMainUI() {
    final state = widget.controller.state;

    // Determine colors based on state
    Color primaryColor;
    Color accentColor;
    bool isInputDisabled = false;

    if (state == SecurityState.LOCKED) {
      bool hasMotion = widget.controller.motionConfidence > 0.05;
      bool hasTouch = widget.controller.touchConfidence > 0.3;

      if (widget.controller.motionConfidence > 0.8) {
        primaryColor = _cyan;
        accentColor = _blue;
      } else if (hasMotion && hasTouch) {
        primaryColor = _cyan;
        accentColor = _purple;
      } else if (hasTouch) {
        primaryColor = _blue;
        accentColor = _cyan;
      } else if (hasMotion) {
        primaryColor = _cyan.withOpacity(0.6);
        accentColor = _blue.withOpacity(0.6);
      } else {
        primaryColor = const Color(0xFF004455);
        accentColor = const Color(0xFF003344);
      }
    } else if (state == SecurityState.VALIDATING) {
      primaryColor = _yellow;
      accentColor = _orange;
      isInputDisabled = true;
    } else if (state == SecurityState.SOFT_LOCK) {
      primaryColor = _orange;
      accentColor = _red;
      isInputDisabled = true;
    } else if (state == SecurityState.HARD_LOCK) {
      primaryColor = _red;
      accentColor = const Color(0xFF8B0000);
      isInputDisabled = true;
    } else if (state == SecurityState.ROOT_WARNING) {
      return _buildRootWarning();
    } else {
      primaryColor = _green;
      accentColor = _cyan;
      isInputDisabled = true;
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 🎮 Layer 1: Animated Grid Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: HexGridPainter(
                    color: primaryColor,
                    rotation: _rotationController.value * 2 * pi,
                  ),
                );
              },
            ),
          ),

          // 🎮 Layer 2: Particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                for (var p in _particles) p.update();
                return CustomPaint(
                  painter: ParticlePainter(
                    particles: _particles,
                    color: primaryColor,
                  ),
                );
              },
            ),
          ),

          // 🎮 Layer 3: Radial HUD Background
          Center(
            child: AnimatedBuilder(
              animation: _hexagonController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(400, 400),
                  painter: RadialHUDPainter(
                    primaryColor: primaryColor,
                    accentColor: accentColor,
                    progress: _hexagonController.value,
                    motionLevel: widget.controller.motionConfidence,
                    touchLevel: widget.controller.touchConfidence,
                  ),
                );
              },
            ),
          ),

          // 🎮 Layer 4: Main Content Container
          Center(
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top HUD
                  _buildTopHUD(primaryColor, accentColor, state),

                  const SizedBox(height: 30),

                  // Wheels Container
                  _buildWheelsSection(primaryColor, isInputDisabled),

                  const SizedBox(height: 30),

                  // Bottom Stats
                  _buildBottomStats(primaryColor, accentColor),

                  const SizedBox(height: 25),

                  // Auth Button
                  _buildHexButton(primaryColor, accentColor, state, isInputDisabled),

                  if (widget.controller.threatMessage.isNotEmpty || _suspiciousRootBypass)
                    _buildThreatAlert(primaryColor),
                ],
              ),
            ),
          ),

          // 🎮 Layer 5: Scan Line Effect
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ScanLinePainter(
                      progress: _scanController.value,
                      color: primaryColor,
                    ),
                  );
                },
              ),
            ),
          ),

          // 🎮 Layer 6: Corner UI Elements
          _buildCornerUI(primaryColor, accentColor),
        ],
      ),
    );
  }

  Widget _buildTopHUD(Color primary, Color accent, SecurityState state) {
    String statusText;
    IconData statusIcon;

    if (state == SecurityState.LOCKED) {
      if (widget.controller.motionConfidence > 0.8) {
        statusText = "KINETIC LOCK ENGAGED";
        statusIcon = Icons.graphic_eq;
      } else if (widget.controller.touchConfidence > 0.3) {
        statusText = "BIOMETRIC ACTIVE";
        statusIcon = Icons.fingerprint;
      } else {
        statusText = "AWAITING INPUT";
        statusIcon = Icons.lock_outline;
      }
    } else if (state == SecurityState.VALIDATING) {
      statusText = "VALIDATING SEQUENCE";
      statusIcon = Icons.sync;
    } else if (state == SecurityState.SOFT_LOCK) {
      statusText = "ACCESS DENIED";
      statusIcon = Icons.warning_amber;
    } else if (state == SecurityState.HARD_LOCK) {
      statusText = "SYSTEM LOCKED";
      statusIcon = Icons.block;
    } else {
      statusText = "ACCESS GRANTED";
      statusIcon = Icons.check_circle;
    }

    return Column(
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: primary.withOpacity(0.5), width: 1),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Icon(
                    statusIcon,
                    color: primary,
                    size: 16,
                    shadows: [
                      Shadow(
                        color: primary,
                        blurRadius: 10 * _pulseController.value,
                      )
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  shadows: [Shadow(color: primary, blurRadius: 8)],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Tech Readout Bar
        Container(
          height: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                primary.withOpacity(0.3),
                accent.withOpacity(0.6),
                primary.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWheelsSection(Color primary, bool disabled) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(color: primary.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Holographic overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withOpacity(0.05),
                      Colors.transparent,
                      primary.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),

            // Wheels
            Center(
              child: IgnorePointer(
                ignoring: disabled,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notif) {
                    if (notif is ScrollStartNotification) {
                      for (int i = 0; i < _scrollControllers.length; i++) {
                        if (_scrollControllers[i].position == notif.metrics) {
                          setState(() => _activeWheelIndex = i);
                          _wheelActiveTimer?.cancel();
                          break;
                        }
                      }
                    } else if (notif is ScrollUpdateNotification) {
                      widget.controller.registerTouch();
                      _analyzeScrollPattern();
                    } else if (notif is ScrollEndNotification) {
                      _wheelActiveTimer = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) setState(() => _activeWheelIndex = null);
                      });
                    }
                    return false;
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (i) => _buildWheel(i, primary, disabled)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheel(int index, Color primary, bool disabled) {
    final isActive = _activeWheelIndex == index;
    final opacity = disabled ? 0.3 : (isActive ? 1.0 : 0.4);

    return SizedBox(
      width: 55,
      child: Stack(
        children: [
          // Glow effect when active
          if (isActive)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.5 * _pulseController.value),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                  );
                },
              ),
            ),

          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: opacity,
            child: ListWheelScrollView.useDelegate(
              controller: _scrollControllers[index],
              itemExtent: 60,
              perspective: 0.003,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (val) {
                HapticFeedback.selectionClick();
                widget.controller.updateWheel(index, val % 10);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, i) {
                  return Center(
                    child: Text(
                      '${i % 10}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        shadows: isActive
                            ? [
                                Shadow(color: primary, blurRadius: 20),
                                Shadow(color: primary, blurRadius: 40),
                              ]
                            : [],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStats(Color primary, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatBox(
          "MOTION",
          widget.controller.motionConfidence,
          primary,
          Icons.sensors,
        ),
        _buildStatBox(
          "TOUCH",
          widget.controller.touchConfidence,
          primary,
          Icons.fingerprint,
        ),
        _buildStatBox(
          "PATTERN",
          _patternScore,
          primary,
          Icons.timeline,
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, double value, Color color, IconData icon) {
    final isActive = value > 0.5;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? color : color.withOpacity(0.3),
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.1),
                    Colors.transparent,
                  ],
                )
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? color : color.withOpacity(0.5),
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : color.withOpacity(0.5),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Stack(
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [BoxShadow(color: color, blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: isActive ? color : color.withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHexButton(Color primary, Color accent, SecurityState state, bool disabled) {
    String buttonText;
    if (state == SecurityState.HARD_LOCK) {
      buttonText = "SYSTEM LOCKED";
    } else if (state == SecurityState.VALIDATING) {
      buttonText = "VALIDATING...";
    } else if (state == SecurityState.UNLOCKED) {
      buttonText = "ACCESS GRANTED";
    } else {
      buttonText = "AUTHENTICATE";
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: disabled ? primary.withOpacity(0.3) : primary,
              width: 2,
            ),
            gradient: disabled
                ? null
                : LinearGradient(
                    colors: [
                      primary.withOpacity(0.2),
                      accent.withOpacity(0.1),
                    ],
                  ),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: primary.withOpacity(0.4 * _pulseController.value),
                      blurRadius: 25,
                      spreadRadius: 3,
                    )
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled
                  ? null
                  : () {
                      widget.controller.validateAttempt(hasPhysicalMovement: true);
                    },
              borderRadius: BorderRadius.circular(8),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state == SecurityState.VALIDATING)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(primary),
                          ),
                        ),
                      ),
                    Text(
                      buttonText,
                      style: TextStyle(
                        color: disabled ? primary.withOpacity(0.5) : primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: disabled ? [] : [Shadow(color: primary, blurRadius: 10)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThreatAlert(Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(0.1),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _suspiciousRootBypass ? "⚠️ ROOT BYPASS DETECTED" : widget.controller.threatMessage,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerUI(Color primary, Color accent) {
    return Stack(
      children: [
        // Top Left
        Positioned(
          top: 20,
          left: 20,
          child: _buildCornerBracket(primary, true, true),
        ),
        // Top Right
        Positioned(
          top: 20,
          right: 20,
          child: _buildCornerBracket(primary, true, false),
        ),
        // Bottom Left
        Positioned(
          bottom: 20,
          left: 20,
          child: _buildCornerBracket(primary, false, true),
        ),
        // Bottom Right
        Positioned(
          bottom: 20,
          right: 20,
          child: _buildCornerBracket(primary, false, false),
        ),
      ],
    );
  }

  Widget _buildCornerBracket(Color color, bool isTop, bool isLeft) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: color.withOpacity(0.6), width: 2) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: color.withOpacity(0.6), width: 2) : BorderSide.none,
          left: isLeft ? BorderSide(color: color.withOpacity(0.6), width: 2) : BorderSide.none,
          right: !isLeft ? BorderSide(color: color.withOpacity(0.6), width: 2) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildRootWarning() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            border: Border.all(color: _orange, width: 2),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _orange.withOpacity(0.3), blurRadius: 30)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security, color: _orange, size: 60),
              const SizedBox(height: 20),
              Text(
                "SECURITY WARNING",
                style: TextStyle(
                  color: _orange,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Rooted device detected. Security features may be compromised.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (_suspiciousRootBypass) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _red.withOpacity(0.2),
                    border: Border.all(color: _red.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "⚠️ Root hiding tools detected",
                    style: TextStyle(
                      color: _red,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => widget.controller.userAcceptsRisk(),
                  child: const Text(
                    "I UNDERSTAND",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
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
// 3. CUSTOM PAINTERS
// ============================================

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color color;

  ParticlePainter({required this.particles, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      paint.color = color.withOpacity(p.life * 0.5);
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

class HexGridPainter extends CustomPainter {
  final Color color;
  final double rotation;

  HexGridPainter({required this.color, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation * 0.1);

    final hexSize = 30.0;
    final rows = (size.height / (hexSize * 1.5)).ceil() + 2;
    final cols = (size.width / (hexSize * sqrt(3))).ceil() + 2;

    for (int row = -rows; row < rows; row++) {
      for (int col = -cols; col < cols; col++) {
        final x = col * hexSize * sqrt(3) + (row % 2) * hexSize * sqrt(3) / 2;
        final y = row * hexSize * 1.5;

        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = pi / 3 * i;
          final px = x + hexSize * cos(angle);
          final py = y + hexSize * sin(angle);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(HexGridPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.color != color;
}

class RadialHUDPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final double progress;
  final double motionLevel;
  final double touchLevel;

  RadialHUDPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.progress,
    required this.motionLevel,
    required this.touchLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer rings
    for (int i = 0; i < 3; i++) {
      final radius = 150.0 + i * 20;
      final paint = Paint()
        ..color = primaryColor.withOpacity(0.1 - i * 0.02)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(center, radius, paint);
    }

    // Rotating segments
    final segmentPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4) + (progress * 2 * pi);
      final x1 = center.dx + 140 * cos(angle);
      final y1 = center.dy + 140 * sin(angle);
      final x2 = center.dx + 160 * cos(angle);
      final y2 = center.dy + 160 * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), segmentPaint);
    }

    // Motion level arc
    if (motionLevel > 0.05) {
      final arcPaint = Paint()
        ..color = accentColor
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 180),
        -pi / 2,
        2 * pi * motionLevel,
        false,
        arcPaint,
      );
    }

    // Touch level arc
    if (touchLevel > 0.05) {
      final arcPaint = Paint()
        ..color = primaryColor
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 190),
        -pi / 2,
        2 * pi * touchLevel,
        false,
        arcPaint,
      );
    }

    // Center glow
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        80,
        [
          primaryColor.withOpacity(0.2),
          primaryColor.withOpacity(0.05),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );

    canvas.drawCircle(center, 80, glowPaint);

    // Tech lines
    final linePaint = Paint()
      ..color = primaryColor.withOpacity(0.4)
      ..strokeWidth = 1;

    for (int i = 0; i < 12; i++) {
      if (i % 3 != 0) continue;
      final angle = i * pi / 6;
      final x1 = center.dx + 100 * cos(angle);
      final y1 = center.dy + 100 * sin(angle);
      final x2 = center.dx + 130 * cos(angle);
      final y2 = center.dy + 130 * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }
  }

  @override
  bool shouldRepaint(RadialHUDPainter oldDelegate) => true;
}

class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    final gradient = ui.Gradient.linear(
      Offset(0, y - 30),
      Offset(0, y + 30),
      [
        Colors.transparent,
        color.withOpacity(0.3),
        color.withOpacity(0.6),
        color.withOpacity(0.3),
        Colors.transparent,
      ],
      [0.0, 0.3, 0.5, 0.7, 1.0],
    );

    final paint = Paint()..shader = gradient;

    canvas.drawRect(
      Rect.fromLTWH(0, y - 30, size.width, 60),
      paint,
    );

    // Main scan line
    final linePaint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
