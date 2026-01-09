// 🎯 PROJECT JARVIS - HOLOGRAPHIC HUD INTERFACE
// Design Inspiration: JARVIS (Iron Man) - Holographic Targeting System
// Integration: Francois (Loyal Butler)

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'cla_controller.dart';
import 'cla_models.dart';

// ============================================
// 1. ML PATTERN ANALYZER
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
      double pressureVariance = _calculateVariance(pressures);
      features.add(pressureVariance);
    } else {
      features.add(0.5);
    }
    
    if (touchData[0].containsKey('speed')) {
      List<double> speeds = touchData.map((e) => e['speed'] as double).toList();
      double speedVariance = _calculateVariance(speeds);
      features.add(speedVariance);
    } else {
      features.add(0.5);
    }
    
    double tremorScore = _detectTremor(touchData);
    features.add(tremorScore);
    
    double humanScore = 0.0;
    humanScore += features[0] * 0.3;
    humanScore += features[1] * 0.2;
    humanScore += features[2] * 0.2;
    humanScore += features[3] * 0.3;
    
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
      if (timeDiff > 80 && timeDiff < 125) {
        microMovements++;
      }
    }
    
    return (microMovements / touchData.length).clamp(0.0, 1.0);
  }
}

// ============================================
// 2. MAIN WIDGET: JARVIS CRYPTEX LOCK
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
  Timer? _screenshotWatchdog;
  
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  late List<FixedExtentScrollController> _scrollControllers;
  
  double _patternScore = 0.0;
  List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;
  
  bool _suspiciousRootBypass = false;
  
  // 🎯 JARVIS Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _reticleController;
  
  // 🎯 JARVIS COLOR PALETTE
  final Color _jarvisCyan = const Color(0xFF00FFFF);
  final Color _jarvisDim = const Color(0xFF004D4D);
  final Color _jarvisGreen = const Color(0xFF00FF88);
  final Color _jarvisRed = const Color(0xFFFF3366);
  final Color _jarvisWarning = const Color(0xFFFFA726);
  final Color _jarvisBackground = const Color(0xFF0A0A0A);

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
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _reticleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }
  
  void _enableAntiScreenshot() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      const platform = MethodChannel('com.cryptex/security');
      platform.invokeMethod('enableScreenshotProtection');
    } catch (e) {
      debugPrint("Screenshot protection: $e");
    }
  }

  void _startScreenshotWatchdog() {
    _screenshotWatchdog = Timer.periodic(const Duration(seconds: 2), (timer) {
      _detectScreenshotAttempt();
    });
  }

  void _detectScreenshotAttempt() async {
    try {
      const platform = MethodChannel('com.cryptex/security');
      final bool screenshotDetected = await platform.invokeMethod('checkScreenshot');
      if (screenshotDetected && mounted) {
        _embedWatermark();
      }
    } catch (e) {}
  }

  void _embedWatermark() {
    setState(() {});
  }

  void _checkRootBypass() async {
    try {
      final List<String> suspiciousPackages = [
        'com.topjohnwu.magisk',
        'eu.chainfire.supersu',
        'com.koushikdutta.superuser',
        'com.thirdparty.superuser',
        'com.zachspong.rootcloak',
      ];
      final List<String> suspiciousPaths = [
        '/system/xbin/su', '/system/bin/su', '/sbin/su',
        '/data/local/su', '/data/local/xbin/su',
      ];
      const platform = MethodChannel('com.cryptex/security');
      final bool detected = await platform.invokeMethod('detectRootBypass', {
        'packages': suspiciousPackages,
        'paths': suspiciousPaths,
      });
      if (detected) {
        setState(() => _suspiciousRootBypass = true);
      }
    } catch (e) {}
  }

  void _handleControllerChange() {
    if (widget.controller.state == SecurityState.UNLOCKED) {
      widget.onSuccess();
    } else if (widget.controller.state == SecurityState.HARD_LOCK) {
      widget.onJammed();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _accelSub?.cancel();
      _accelSub = null;
      _lockoutTimer?.cancel();
      _screenshotWatchdog?.cancel();
      _wheelActiveTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_accelSub == null) _startListening();
      if (widget.controller.state == SecurityState.HARD_LOCK) _startLockoutTimer();
      _startScreenshotWatchdog();
    }
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (index) {
      int startVal = widget.controller.getInitialValue(index);
      return FixedExtentScrollController(initialItem: startVal);
    });
  }

  void _startListening() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEvents.listen((UserAccelerometerEvent e) {
      double rawMag = e.x.abs() + e.y.abs() + e.z.abs();
      widget.controller.registerShake(rawMag, e.x, e.y, e.z);
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
      'timestamp': now, 'speed': speed, 'pressure': 0.5, 'wheelIndex': _activeWheelIndex ?? 0,
    });
    if (_touchData.length > 20) _touchData.removeAt(0);
    if (_touchData.length >= 5) {
      _patternScore = MLPatternAnalyzer.analyzePattern(_touchData);
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
    _pulseController.dispose();
    _scanController.dispose();
    _reticleController.dispose();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  void _triggerHaptic() { HapticFeedback.selectionClick(); }

  @override
  Widget build(BuildContext context) {
    return _buildStateUI(widget.controller.state);
  }

  Widget _buildStateUI(SecurityState state) {
    Color activeColor;
    Color boxColor;
    String statusText;
    IconData statusIcon;
    bool isInputDisabled = false;

    if (state == SecurityState.LOCKED) {
       bool hasMotion = widget.controller.motionConfidence > 0.05;
       bool hasTouch = widget.controller.touchConfidence > 0.3;
       if (widget.controller.motionConfidence > 0.8) {
         activeColor = _jarvisCyan; statusText = "MOTION SIGNATURE ACQUIRED"; statusIcon = Icons.graphic_eq;
       } else if (hasMotion && hasTouch) {
         activeColor = _jarvisCyan; statusText = "BIOMETRIC SYNC ACTIVE"; statusIcon = Icons.sensors;
       } else if (hasTouch) {
         activeColor = _jarvisCyan; statusText = "TOUCH PATTERN ANALYZING"; statusIcon = Icons.touch_app;
       } else if (hasMotion) {
         activeColor = _jarvisCyan.withOpacity(0.7); statusText = "MOTION TRACKING..."; statusIcon = Icons.radar;
       } else {
         activeColor = _jarvisDim; statusText = "AWAITING AUTHENTICATION"; statusIcon = Icons.lock_outline;
       }
       boxColor = _jarvisCyan;
    } else if (state == SecurityState.VALIDATING) {
        activeColor = Colors.white; boxColor = Colors.white; statusText = "CREDENTIAL VERIFICATION"; statusIcon = Icons.cloud_sync; isInputDisabled = true;
    } else if (state == SecurityState.SOFT_LOCK) {
        activeColor = _jarvisRed; boxColor = _jarvisRed; statusText = "ACCESS DENIED - ATTEMPT ${widget.controller.failedAttempts}/3"; statusIcon = Icons.warning_amber_rounded; isInputDisabled = true;
    } else if (state == SecurityState.HARD_LOCK) {
        activeColor = _jarvisRed; boxColor = _jarvisRed; statusText = "SECURITY LOCKDOWN ENGAGED"; statusIcon = Icons.block; isInputDisabled = true;
    } else if (state == SecurityState.ROOT_WARNING) {
        return _buildSecurityWarningUI(); 
    } else { 
        activeColor = _jarvisGreen; boxColor = _jarvisGreen; statusText = "ACCESS AUTHORIZED"; statusIcon = Icons.lock_open; isInputDisabled = true;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CustomPaint(painter: JarvisGridPainter(color: activeColor)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: _jarvisBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: activeColor.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 40, spreadRadius: 3),
              BoxShadow(color: activeColor.withOpacity(0.15), blurRadius: 60, spreadRadius: 6)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  _buildHUDCorner(activeColor, true, true),
                  _buildHUDCorner(activeColor, true, false),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(statusIcon, color: activeColor, size: 20),
                                const SizedBox(width: 8),
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(colors: [activeColor, activeColor.withOpacity(0.5)]).createShader(bounds),
                                  child: const Text("J.A.R.V.I.S. SYSTEM", style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 3.0, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Text(statusText, style: TextStyle(color: activeColor, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.0, height: 1.3, shadows: [
                                  Shadow(color: activeColor.withOpacity(0.9), blurRadius: 20 * (0.5 + 0.5 * _pulseController.value)),
                                  Shadow(color: activeColor.withOpacity(0.6), blurRadius: 35 * (0.5 + 0.5 * _pulseController.value)),
                                ]));
                              },
                            ),
                            const SizedBox(height: 12),
                            Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, activeColor.withOpacity(0.4), activeColor.withOpacity(0.7), activeColor.withOpacity(0.4), Colors.transparent]))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                           _buildSensorBox(label: "MOTION", value: widget.controller.motionConfidence, color: boxColor, icon: Icons.sensors),
                           const SizedBox(height: 10),
                           _buildSensorBox(label: "TOUCH", value: widget.controller.touchConfidence, color: boxColor, icon: Icons.fingerprint),
                           const SizedBox(height: 10),
                           _buildPatternBox(label: "PATTERN", score: _patternScore, color: boxColor),
                        ],
                      )
                    ],
                  ),
                ],
              ),
              if (widget.controller.threatMessage.isNotEmpty || _suspiciousRootBypass) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: _jarvisRed.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _jarvisRed.withOpacity(0.5), width: 1.5)),
                  child: Row(children: [Icon(Icons.error_outline, color: _jarvisRed, size: 20), const SizedBox(width: 12), Expanded(child: Text(_suspiciousRootBypass ? "⚠️ ROOT BYPASS DETECTION" : widget.controller.threatMessage, style: TextStyle(color: _jarvisRed, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)))]),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                height: 140,
                child: Stack(
                  children: [
                    Positioned(left: 0, top: 0, bottom: 0, child: CustomPaint(size: const Size(40, 140), painter: JarvisPeripheralPainter(color: activeColor, side: 'left'))),
                    Positioned(right: 0, top: 0, bottom: 0, child: CustomPaint(size: const Size(40, 140), painter: JarvisPeripheralPainter(color: activeColor, side: 'right'))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50),
                      child: IgnorePointer(
                        ignoring: isInputDisabled,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollStartNotification) {
                              for (int i = 0; i < _scrollControllers.length; i++) {
                                if (_scrollControllers[i].position == notification.metrics) {
                                  setState(() { _activeWheelIndex = i; }); _wheelActiveTimer?.cancel(); break;
                                }
                              }
                            } else if (notification is ScrollUpdateNotification) {
                              widget.controller.registerTouch(); _analyzeScrollPattern();
                            } else if (notification is ScrollEndNotification) {
                              _wheelActiveTimer?.cancel(); _wheelActiveTimer = Timer(const Duration(milliseconds: 300), () { if (mounted) setState(() => _activeWheelIndex = null); });
                            }
                            return false;
                          },
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(5, (index) => _buildHolographicTumbler(index, activeColor, isInputDisabled))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildAuthButton(state, activeColor, isInputDisabled),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHUDCorner(Color color, bool isTop, bool isLeft) {
    return Positioned(top: isTop ? 0 : null, bottom: !isTop ? 0 : null, left: isLeft ? 0 : null, right: !isLeft ? 0 : null, child: Container(width: 32, height: 32, decoration: BoxDecoration(border: Border(top: isTop ? BorderSide(color: color.withOpacity(0.8), width: 2.5) : BorderSide.none, bottom: !isTop ? BorderSide(color: color.withOpacity(0.8), width: 2.5) : BorderSide.none, left: isLeft ? BorderSide(color: color.withOpacity(0.8), width: 2.5) : BorderSide.none, right: !isLeft ? BorderSide(color: color.withOpacity(0.8), width: 2.5) : BorderSide.none)), child: CustomPaint(painter: CornerDotPainter(color: color, isTop: isTop, isLeft: isLeft))));
  }
  
  Widget _buildSensorBox({required String label, required double value, required Color color, required IconData icon}) {
    bool isSensing = value > 0.05; bool isMatching = value > 0.6;
    Color displayColor = isMatching ? _jarvisGreen : (isSensing ? _jarvisRed : color);
    return Column(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), width: 60, height: 48, decoration: BoxDecoration(color: isMatching ? displayColor.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSensing ? displayColor : const Color(0xFF333333), width: isSensing ? 2.5 : 1.5)), child: Center(child: Icon(isMatching ? Icons.check_circle : icon, size: 22, color: isSensing ? displayColor : const Color(0xFF666666)))), const SizedBox(height: 5), Text(label, style: TextStyle(fontSize: 8, color: isSensing ? displayColor.withOpacity(0.9) : const Color(0xFF666666), fontWeight: FontWeight.w800, letterSpacing: 1.0))]);
  }

  Widget _buildPatternBox({required String label, required double score, required Color color}) {
    bool isHumanLike = score >= 0.5; bool hasData = score > 0;
    Color boxColor = isHumanLike ? _jarvisGreen : (hasData ? _jarvisRed : const Color(0xFF333333));
    return Column(children: [AnimatedContainer(duration: const Duration(milliseconds: 300), width: 60, height: 48, decoration: BoxDecoration(color: isHumanLike ? boxColor.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: boxColor, width: hasData ? 2.5 : 1.5)), child: Center(child: Icon(isHumanLike ? Icons.check_circle : (hasData ? Icons.close : Icons.timeline), size: 22, color: boxColor))), const SizedBox(height: 5), Text(label, style: TextStyle(fontSize: 8, color: hasData ? boxColor.withOpacity(0.9) : const Color(0xFF666666), fontWeight: FontWeight.w800, letterSpacing: 1.0))]);
  }

  Widget _buildHolographicTumbler(int index, Color color, bool disabled) {
    final bool isActive = (_activeWheelIndex == index);
    return SizedBox(width: 52, child: Listener(onPointerDown: (_) { if (!disabled) { setState(() { _activeWheelIndex = index; }); _wheelActiveTimer?.cancel(); } }, child: AnimatedOpacity(duration: const Duration(milliseconds: 250), opacity: disabled ? 0.3 : (isActive ? 1.0 : 0.4), child: Stack(children: [
      if (isActive) Positioned.fill(child: AnimatedBuilder(animation: _reticleController, builder: (context, child) => CustomPaint(painter: JarvisReticlePainter(color: color, progress: _reticleController.value)))),
      if (isActive) Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.6), width: 2.5), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 25)]))),
      if (isActive) Positioned.fill(child: AnimatedBuilder(animation: _scanController, builder: (context, child) => CustomPaint(painter: ScanLinePainter(color: color, progress: _scanController.value)))),
      ListWheelScrollView.useDelegate(controller: _scrollControllers[index], itemExtent: 50, perspective: 0.003, diameterRatio: 1.1, physics: const FixedExtentScrollPhysics(), onSelectedItemChanged: (val) { _triggerHaptic(); widget.controller.updateWheel(index, val % 10); }, childDelegate: ListWheelChildBuilderDelegate(builder: (context, i) => Center(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 250), style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, shadows: isActive ? [Shadow(color: color, blurRadius: 25)] : []), child: Text('${i % 10}'))))),
    ]))));
  }

  Widget _buildAuthButton(SecurityState state, Color activeColor, bool isInputDisabled) {
    return SizedBox(width: double.infinity, child: AnimatedContainer(duration: const Duration(milliseconds: 300), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: !isInputDisabled ? [BoxShadow(color: activeColor.withOpacity(0.4), blurRadius: 25)] : []), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isInputDisabled ? const Color(0xFF1A1A1A) : activeColor.withOpacity(0.25), foregroundColor: isInputDisabled ? const Color(0xFF666666) : activeColor, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isInputDisabled ? const Color(0xFF333333) : activeColor, width: 2.5))), onPressed: isInputDisabled ? null : () => widget.controller.validateAttempt(hasPhysicalMovement: true), child: Text(state == SecurityState.HARD_LOCK ? "SECURITY LOCKDOWN" : "INITIATE AUTHENTICATION", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.0, fontSize: 14)))));
  }

  Widget _buildSecurityWarningUI() {
    return Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24), border: Border.all(color: _jarvisWarning, width: 2.5)), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shield_outlined, color: _jarvisWarning, size: 56), const SizedBox(height: 24), Text("Security Protocol Alert", style: TextStyle(color: _jarvisWarning, fontWeight: FontWeight.w900, fontSize: 22)), const SizedBox(height: 16), const Text("Rooted devices compromise security protocols.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 28), SizedBox(width: double.infinity, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _jarvisWarning, foregroundColor: Colors.black), onPressed: () => widget.controller.userAcceptsRisk(), child: const Text("ACKNOWLEDGE RISK", style: TextStyle(fontWeight: FontWeight.w900))))]));
  }
}

// ============================================
// 4. CUSTOM PAINTERS
// ============================================

class JarvisGridPainter extends CustomPainter {
  final Color color;
  JarvisGridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.06)..strokeWidth = 1..style = PaintingStyle.stroke;
    for (double x = 0; x < size.width; x += 45) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 45) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(JarvisGridPainter oldDelegate) => oldDelegate.color != color;
}

class ScanLinePainter extends CustomPainter {
  final Color color; final double progress;
  ScanLinePainter({required this.color, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2.5..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, color.withOpacity(0.9), Colors.transparent]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawLine(Offset(0, size.height * progress), Offset(size.width, size.height * progress), paint);
  }
  @override
  bool shouldRepaint(ScanLinePainter oldDelegate) => oldDelegate.progress != progress;
}

class JarvisReticlePainter extends CustomPainter {
  final Color color; final double progress;
  JarvisReticlePainter({required this.color, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = color.withOpacity(0.6)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    canvas.save(); canvas.translate(center.dx, center.dy); canvas.rotate(progress * 2 * pi); canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(center, 20, paint);
    for (int i = 0; i < 4; i++) {
      final angle = (i * pi / 2);
      canvas.drawLine(Offset(center.dx + 18 * cos(angle), center.dy + 18 * sin(angle)), Offset(center.dx + 22 * cos(angle), center.dy + 22 * sin(angle)), paint);
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(JarvisReticlePainter oldDelegate) => oldDelegate.progress != progress;
}

class JarvisPeripheralPainter extends CustomPainter {
  final Color color; final String side;
  JarvisPeripheralPainter({required this.color, required this.side});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.4)..strokeWidth = 1.0..style = PaintingStyle.stroke;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    if (side == 'left') {
      canvas.drawRect(const Rect.fromLTWH(0, 10, 38, 14), Paint()..color = color.withOpacity(0.2));
      tp.text = TextSpan(text: 'COORD', style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold));
      tp.layout(); tp.paint(canvas, const Offset(4, 13));
    } else {
      canvas.drawRect(const Rect.fromLTWH(2, 10, 38, 14), Paint()..color = color.withOpacity(0.2));
      tp.text = TextSpan(text: 'SYS-ID', style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold));
      tp.layout(); tp.paint(canvas, const Offset(6, 13));
    }
  }
  @override
  bool shouldRepaint(JarvisPeripheralPainter oldDelegate) => oldDelegate.color != color;
}

class CornerDotPainter extends CustomPainter {
  final Color color; final bool isTop, isLeft;
  CornerDotPainter({required this.color, required this.isTop, required this.isLeft});
  @override
  void paint(Canvas canvas, Size size) {
    final dotX = isLeft ? 4.0 : size.width - 4.0; final dotY = isTop ? 4.0 : size.height - 4.0;
    canvas.drawCircle(Offset(dotX, dotY), 2.5, Paint()..color = color);
  }
  @override
  bool shouldRepaint(CornerDotPainter oldDelegate) => false;
}
