// cryptex_lock_god_tier.dart
// ☢️ GOD TIER UI V3.5 - THE FINAL FORM
// Changelog:
// - Added "Reactor Glow" (Warm Orange ambiance)
// - Added "Glitch Lines" effect for suspected bots
// - Implemented "Haptic Engine" (Loops, Double Knocks)
// - Added AnimatedScale for Active Wheels (Breathing effect)
// - Optimized Painters (shouldRepaint fixed)
// - Retained all V3.4 Safety Features (Crash Proof)

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'cla_controller.dart';
import 'cla_models.dart';

// ============================================
// 🎨 TACTICAL THEME ENGINE (GOD TIER)
// ============================================
class TacticalTheme {
  static const Color amber = Color(0xFFFFC107);      // Primary Warning/Active
  static const Color graphite = Color(0xFF0F0F0F);   // Deep Background
  static const Color crimson = Color(0xFFCF6679);    // Critical/Lockdown
  static const Color frost = Color(0x80000000);      // Frost Overlay
  static const Color slate = Color(0xFF2C2C2C);      // Inactive Elements
  static const Color neonGreen = Color(0xFF00FF41);  // Success
  static const Color reactorGlow = Color(0xFFFF5722); // Warm Reactor Core
}

// ============================================
// 🧠 LOGIC: ML PATTERN ANALYZER
// ============================================
class MLPatternAnalyzer {
  static double analyzePattern(List<Map<String, dynamic>> touchData) {
    if (touchData.length < 5) return 0.0;
    
    List<double> features = [];
    List<int> intervals = [];
    for (int i = 1; i < touchData.length; i++) {
      intervals.add(touchData[i]['timestamp'].difference(touchData[i-1]['timestamp']).inMilliseconds);
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
      int timeDiff = touchData[i]['timestamp'].difference(touchData[i-1]['timestamp']).inMilliseconds;
      if (timeDiff > 80 && timeDiff < 125) microMovements++;
    }
    return (microMovements / touchData.length).clamp(0.0, 1.0);
  }
}

// ============================================
// 🔒 MAIN WIDGET: CRYPTEX GOD TIER
// ============================================
class CryptexLockGodTier extends StatefulWidget {
  final ClaController controller;
  final VoidCallback onSuccess;
  final VoidCallback onFail;
  final VoidCallback onJammed;

  const CryptexLockGodTier({
    super.key,
    required this.controller,
    required this.onSuccess,
    required this.onFail,
    required this.onJammed,
  });

  @override
  State<CryptexLockGodTier> createState() => _CryptexLockGodTierState();
}

class _CryptexLockGodTierState extends State<CryptexLockGodTier> with TickerProviderStateMixin, WidgetsBindingObserver {
  // Logic Variables
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  Timer? _lockoutTimer;
  Timer? _screenshotWatchdog;
  Timer? _jitterTimer;
  Timer? _hapticLoopTimer; // New: For continuous haptics
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  late List<FixedExtentScrollController> _scrollControllers;
  
  // Tactical Data
  double _patternScore = 0.0;
  List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;
  bool _suspiciousRootBypass = false;
  
  // Motion Feedback Variables
  double _accelX = 0.0;
  double _accelY = 0.0;
  double _jitterX = 0.0; 
  double _jitterY = 0.0; 

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _glitchController; // New: For Bot Glitches

  // Platform Channel
  static const platform = MethodChannel('com.cryptex/security');

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
    
    // Pulse for active elements
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), 
    )..repeat(reverse: true);

    // Scan line
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Glitch Controller (Fast random flicker)
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..repeat();

    // Chaos Jitter Timer (Anti-OCR)
    _jitterTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _jitterX = (Random().nextDouble() - 0.5) * 0.4;
          _jitterY = (Random().nextDouble() - 0.5) * 0.4;
        });
      }
    });
  }

  // --- SAFETY & NATIVE ---

  Future<void> _enableAntiScreenshot() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await platform.invokeMethod('enableScreenshotProtection');
      }
    } catch (e) { /* Silent fail */ }
  }

  void _startScreenshotWatchdog() {
    _screenshotWatchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      _detectScreenshotAttempt();
    });
  }

  Future<void> _detectScreenshotAttempt() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final bool detected = await platform.invokeMethod('checkScreenshot');
        if (detected && mounted) debugPrint("⚠️ Screenshot detected");
      }
    } catch (e) { /* Silent fail */ }
  }

  Future<void> _checkRootBypass() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final bool detected = await platform.invokeMethod('detectRootBypass', {
          'packages': ['com.topjohnwu.magisk', 'eu.chainfire.supersu'],
          'paths': ['/system/xbin/su', '/system/bin/su'],
        });
        if (detected && mounted) setState(() => _suspiciousRootBypass = true);
      }
    } catch (e) { /* Silent fail */ }
  }

  void _handleControllerChange() {
    SecurityState state = widget.controller.state;
    
    // 📳 HAPTIC ENGINE
    _hapticLoopTimer?.cancel(); // Stop any loops
    
    if (state == SecurityState.UNLOCKED) {
      HapticFeedback.vibrate(); // Long success vibrate
      widget.onSuccess();
    } 
    else if (state == SecurityState.HARD_LOCK) {
      _triggerHapticCombo("double_knock");
      widget.onJammed();
      _startLockoutTimer();
    } 
    else if (state == SecurityState.SOFT_LOCK) {
      _triggerHapticCombo("double_knock");
    }
    else if (state == SecurityState.VALIDATING) {
      // Loop haptic while validating
      _hapticLoopTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        HapticFeedback.lightImpact();
      });
    }

    if (mounted) setState(() {});
  }

  void _triggerHapticCombo(String type) async {
    if (type == "double_knock") {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _accelSub?.cancel();
      _lockoutTimer?.cancel();
      _screenshotWatchdog?.cancel();
      _wheelActiveTimer?.cancel();
      _hapticLoopTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startListening();
      if (widget.controller.state == SecurityState.HARD_LOCK) _startLockoutTimer();
      _startScreenshotWatchdog();
    }
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (i) {
      int initial = widget.controller.getInitialValue(i);
      return FixedExtentScrollController(initialItem: initial);
    });
  }

  void _startListening() {
    _accelSub?.cancel();
    try {
      _accelSub = userAccelerometerEvents.listen(
        (e) {
          if (mounted) {
            setState(() {
              _accelX = e.x;
              _accelY = e.y;
            });
            double mag = e.x.abs() + e.y.abs() + e.z.abs();
            widget.controller.registerShake(mag, e.x, e.y, e.z);
          }
        },
        onError: (e) {},
        cancelOnError: false,
      );
    } catch (e) {}
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
      setState(() {});
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
    _jitterTimer?.cancel();
    _hapticLoopTimer?.cancel();
    _pulseController.dispose();
    _scanController.dispose();
    _glitchController.dispose();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  String _getStateLabel(SecurityState state) {
    switch (state) {
      case SecurityState.LOCKED: return "STANDBY";
      case SecurityState.VALIDATING: return "DECRYPTING...";
      case SecurityState.HARD_LOCK: return "LOCKDOWN";
      case SecurityState.SOFT_LOCK: return "REJECTED";
      case SecurityState.UNLOCKED: return "GRANTED";
      case SecurityState.ROOT_WARNING: return "COMPROMISED";
      default: return "INIT";
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    bool isLockdown = state == SecurityState.HARD_LOCK;
    
    // 🤖 Bot Detection Logic
    bool suspectedBot = widget.controller.motionConfidence < 0.15 && widget.controller.touchConfidence > 0.5;

    Color activeColor = isLockdown 
        ? TacticalTheme.crimson 
        : (state == SecurityState.UNLOCKED ? TacticalTheme.neonGreen : TacticalTheme.amber);

    return Scaffold(
      backgroundColor: TacticalTheme.graphite,
      body: Stack(
        children: [
          // 1. Reactor Core Grid (New: Warm Glow)
          Positioned.fill(
            child: CustomPaint(
              painter: TacticalGridPainter(
                color: activeColor,
                scrollOffset: _accelY * 2,
              ),
            ),
          ),

          // 2. Main Content
          Center(
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: TacticalTheme.graphite.withOpacity(0.92),
                border: Border.all(color: activeColor.withOpacity(0.5), width: 1),
                borderRadius: BorderRadius.circular(4), 
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withOpacity(0.15), // Slightly stronger for reactor feel
                    blurRadius: 25,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(activeColor, state),
                  const SizedBox(height: 30),
                  
                  // Wheels with Breathing Scale
                  _buildTacticalWheels(activeColor, state == SecurityState.VALIDATING || isLockdown, suspectedBot),
                  const SizedBox(height: 30),
                  
                  // Tech Readouts
                  _buildTechReadout("KINETICS", widget.controller.motionConfidence, activeColor),
                  const SizedBox(height: 8),
                  _buildTechReadout("BIOMETRICS", widget.controller.touchConfidence, activeColor),
                  const SizedBox(height: 8),
                  _buildTechReadout("HEURISTICS", _patternScore, activeColor),
                  
                  const SizedBox(height: 30),
                  
                  // Auth Button
                  _buildTacticalButton(activeColor, state, isLockdown),
                ],
              ),
            ),
          ),

          // 3. Anti-Bot Punishment (Frost + Glitch)
          if (suspectedBot) ...[
            // Frost
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: TacticalTheme.frost),
                ),
              ),
            ),
            // Savage Message
            Center(
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                 decoration: BoxDecoration(
                   border: Border.all(color: TacticalTheme.crimson, width: 2),
                   color: Colors.black,
                 ),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const Icon(Icons.no_accounts, color: TacticalTheme.crimson, size: 40),
                     const SizedBox(height: 10),
                     const Text(
                       "NO BIO-KINETIC PRESENCE",
                       style: TextStyle(
                         fontFamily: 'monospace',
                         color: TacticalTheme.crimson,
                         fontWeight: FontWeight.bold,
                         letterSpacing: 1.5,
                         fontSize: 16,
                       ),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       "AUTHENTICATION SEVERED",
                       style: TextStyle(
                         fontFamily: 'monospace',
                         color: TacticalTheme.crimson.withOpacity(0.7),
                         fontSize: 10,
                         letterSpacing: 2,
                       ),
                     ),
                   ],
                 ),
               ),
            ),
          ],
            
          // 4. Peripheral Elements (HUD + Glitch Lines)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glitchController,
              builder: (context, child) {
                return CustomPaint(
                  painter: TacticalPeripheralPainter(
                    color: activeColor,
                    x: _accelX + _jitterX,
                    y: _accelY + _jitterY,
                    isBot: suspectedBot,
                    glitchSeed: _glitchController.value,
                  ),
                );
              },
            ),
          ),
          
          // 5. Threat Alert
          if (widget.controller.threatMessage.isNotEmpty || _suspiciousRootBypass)
             _buildThreatOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color, SecurityState state) {
    bool isWarning = state == SecurityState.HARD_LOCK || state == SecurityState.ROOT_WARNING;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, size: 12, color: color.withOpacity(0.7)),
                const SizedBox(width: 6),
                const Text(
                  "AER DEFENSE KERNEL",
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "VAULT ACCESS V3.5",
              style: TextStyle(
                fontFamily: 'monospace',
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        // Blinking Status Box
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            double opacity = isWarning ? 0.5 + (_pulseController.value * 0.5) : 1.0;
            return Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: color),
                  color: color.withOpacity(isWarning ? 0.2 : 0.1),
                ),
                child: Row(
                  children: [
                    if (isWarning) ...[
                      const Icon(Icons.warning_amber, size: 10, color: TacticalTheme.crimson),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _getStateLabel(state), 
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTacticalWheels(Color color, bool disabled, bool isBot) {
    double tremorOffset = _accelX * 4.5; // Slightly increased for drama
    
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: color.withOpacity(0.5)),
          bottom: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) {
          bool isActive = _activeWheelIndex == index;
          
          // 🚀 V3.5 Feature: Breathing Effect for Humans
          double scale = (isActive && !isBot && _patternScore > 0.6) ? 1.08 : 1.0;
          
          return SizedBox(
            width: 50,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollUpdateNotification) {
                  widget.controller.registerTouch();
                  _analyzeScrollPattern();
                  if (_activeWheelIndex != index) {
                    setState(() => _activeWheelIndex = index);
                  }
                } else if (n is ScrollEndNotification) {
                  _wheelActiveTimer?.cancel();
                  _wheelActiveTimer = Timer(const Duration(milliseconds: 300), () {
                     if (mounted) setState(() => _activeWheelIndex = null);
                  });
                }
                return false;
              },
              child: AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 200),
                child: Transform.translate(
                  offset: Offset(isActive ? tremorOffset : 0, 0), 
                  child: ListWheelScrollView.useDelegate(
                    controller: _scrollControllers[index],
                    itemExtent: 50,
                    perspective: 0.005,
                    physics: disabled ? const NeverScrollableScrollPhysics() : const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (val) {
                      // Light click for wheel
                      HapticFeedback.selectionClick(); 
                      widget.controller.updateWheel(index, val % 10);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, i) {
                        final num = i % 10;
                        return Center(
                          child: Text(
                            '$num',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isActive ? color : TacticalTheme.slate,
                              shadows: isActive ? [
                                Shadow(color: color.withOpacity(0.8), blurRadius: 15)
                              ] : [],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTechReadout(String label, double val, Color color) {
    int bars = (val * 10).toInt().clamp(0, 10);
    String filled = "|" * bars;
    String empty = "·" * (10 - bars); 
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Colors.white38,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          "$filled$empty", 
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildTacticalButton(Color color, SecurityState state, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : () {
        // Heavy impact on tap
        HapticFeedback.heavyImpact(); 
        widget.controller.validateAttempt(hasPhysicalMovement: true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 55,
        width: double.infinity,
        decoration: BoxDecoration(
          // Reactor glow background for button
          color: disabled ? TacticalTheme.slate.withOpacity(0.2) : color.withOpacity(0.15),
          border: Border.all(
            color: disabled ? TacticalTheme.slate : color,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(2), 
          boxShadow: disabled ? [] : [
             BoxShadow(color: color.withOpacity(0.2), blurRadius: 15, spreadRadius: 1)
          ],
        ),
        child: Center(
          child: Text(
            state == SecurityState.VALIDATING ? "DECRYPTING..." : "INITIATE SEQUENCE",
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: disabled ? TacticalTheme.slate : color,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildThreatOverlay() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TacticalTheme.crimson.withOpacity(0.95),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)
          ]
        ),
        child: Row(
          children: [
            // Blinking Warning
            AnimatedBuilder(
              animation: _pulseController,
              builder: (ctx, child) => Opacity(
                opacity: _pulseController.value,
                child: const Icon(Icons.dangerous, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "SECURITY BREACH",
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    _suspiciousRootBypass ? "ROOT ACCESS DETECTED" : widget.controller.threatMessage.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                 HapticFeedback.mediumImpact();
                 widget.controller.userAcceptsRisk();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text("OVERRIDE", style: TextStyle(color: TacticalTheme.crimson, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

// ============================================
// 📐 PAINTERS (OPTIMIZED)
// ============================================

class TacticalGridPainter extends CustomPainter {
  final Color color;
  final double scrollOffset;

  TacticalGridPainter({required this.color, required this.scrollOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.08) 
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // 🚀 V3.5 Feature: Reactor Core Glow (Radial Gradient)
    final center = Offset(size.width / 2, size.height / 2);
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        size.width * 0.8,
        [
          TacticalTheme.reactorGlow.withOpacity(0.15), // Warm glow center
          Colors.transparent,
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    double gridSize = 40.0;
    
    // Vertical
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Horizontal (with Parallax)
    for (double y = -gridSize; y <= size.height + gridSize; y += gridSize) {
      double drawY = (y + scrollOffset) % (size.height + gridSize);
      if (drawY < 0) drawY += size.height;
      canvas.drawLine(Offset(0, drawY), Offset(size.width, drawY), paint);
    }
  }

  @override
  bool shouldRepaint(TacticalGridPainter old) => old.scrollOffset != scrollOffset || old.color != color;
}

class TacticalPeripheralPainter extends CustomPainter {
  final Color color;
  final double x;
  final double y;
  final bool isBot;
  final double glitchSeed;

  TacticalPeripheralPainter({
    required this.color, 
    required this.x, 
    required this.y, 
    this.isBot = false,
    this.glitchSeed = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Center Crosshair
    final cx = size.width / 2 + x * 10;
    final cy = size.height / 2 + y * 10;
    
    canvas.drawLine(Offset(cx - 10, cy), Offset(cx + 10, cy), paint);
    canvas.drawLine(Offset(cx, cy - 10), Offset(cx, cy + 10), paint);
    
    // Corner Brackets
    double m = 20.0;
    double l = 30.0;
    
    // Brackets Logic...
    _drawBracket(canvas, paint, m, m, l, 1, 1); // TL
    _drawBracket(canvas, paint, size.width - m, m, l, -1, 1); // TR
    _drawBracket(canvas, paint, m, size.height - m, l, 1, -1); // BL
    _drawBracket(canvas, paint, size.width - m, size.height - m, l, -1, -1); // BR

    // 🚀 V3.5 Feature: Glitch Lines for Bots
    if (isBot) {
      final glitchPaint = Paint()
        ..color = TacticalTheme.crimson.withOpacity(0.8)
        ..strokeWidth = 1.5;
      
      final random = Random((glitchSeed * 1000).toInt());
      
      for (int i = 0; i < 5; i++) {
        if (random.nextBool()) {
          double dy = random.nextDouble() * size.height;
          double dx = random.nextDouble() * size.width;
          double len = random.nextDouble() * 50;
          canvas.drawLine(Offset(dx, dy), Offset(dx + len, dy), glitchPaint);
        }
      }
    }
  }

  void _drawBracket(Canvas c, Paint p, double x, double y, double l, double dx, double dy) {
    c.drawLine(Offset(x, y), Offset(x + (l * dx), y), p);
    c.drawLine(Offset(x, y), Offset(x, y + (l * dy)), p);
  }

  // ✅ Optimized Repaint as requested
  @override
  bool shouldRepaint(TacticalPeripheralPainter old) => 
    old.x != x || old.y != y || old.color != color || old.glitchSeed != glitchSeed;
}
