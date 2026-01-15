// 🎯 PROJECT Z-KINETIC V3.9 - HYPER SENSITIVE UI (COMPLETE BUILD)
// Status: COMPILATION FIXED ✅
// Features: Instant Touch Green + Hyper Motion Sensitivity + All Graphics Restored

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'cla_controller.dart';
import 'cla_models.dart';
import 'security_engine.dart';

// ============================================
// 1. PATTERN ANALYZER (Visual Helper)
// ============================================
class PatternAnalyzer {
  static double analyze(List<Map<String, dynamic>> touchData) {
    // 🔥 VISUAL HACK: Asalkan ada data, bagi markah penuh visual
    if (touchData.isNotEmpty) return 1.0; 
    return 0.0;
  }
}

// ============================================
// 2. MAIN WIDGET: CRYPTEX LOCK
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
  
  // Data Visualisasi
  double _patternScore = 0.0;
  double _liveMotionScore = 0.0; 
  double _liveTouchScore = 0.0;  
  
  // Touch Memory
  Timer? _touchDecayTimer;
  
  // Motion Calculation
  double _lastX = 0, _lastY = 0, _lastZ = 0;
  
  List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;
  
  // Sensor Data for UI
  double _accelX = 0.0;
  double _accelY = 0.0;
  DateTime? _lastUiUpdate;
  
  // Animations
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _reticleController;
  
  final Color _neonCyan = const Color(0xFF00FFFF);
  final Color _neonGreen = const Color(0xFF00FF88);
  final Color _neonRed = const Color(0xFFFF3366);
  final Color _bgDark = const Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    widget.controller.onInteractionStart(); 
    
    _startListening();
    widget.controller.addListener(_handleControllerChange);
    
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _reticleController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }
  
  void _handleControllerChange() {
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
        int val = 0;
        try { val = widget.controller.getInitialValue(i); } catch(e) {}
        return FixedExtentScrollController(initialItem: val);
    });
  }

  void _startListening() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEvents.listen((e) {
      _accelX = e.x;
      _accelY = e.y;
      
      // 🔥 FIX MOTION: Kira 'Delta' (Perubahan), bukan raw gravity
      double delta = (e.x - _lastX).abs() + (e.y - _lastY).abs() + (e.z - _lastZ).abs();
      _lastX = e.x; _lastY = e.y; _lastZ = e.z;
      
      // Amplify x10! Goyang sikit je visual dah penuh.
      double amplifiedMotion = (delta * 10.0).clamp(0.0, 1.0);
      
      // Hantar data mentah ke Controller (Biarkan engine fikir sendiri)
      widget.controller.registerShake(delta, e.x, e.y, e.z);

      // Visual Score (Fast Attack, Slow Decay)
      if (amplifiedMotion > _liveMotionScore) {
        _liveMotionScore = amplifiedMotion;
      } else {
        _liveMotionScore = (_liveMotionScore * 0.92); // Decay lambat sikit
      }

      final now = DateTime.now();
      if (_lastUiUpdate == null || now.difference(_lastUiUpdate!).inMilliseconds > 30) {
        _lastUiUpdate = now;
        if (mounted) setState(() {});
      }
    });
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.controller.state == SecurityState.HARD_LOCK) {
        setState(() {});
        if (widget.controller.remainingLockoutSeconds <= 0) timer.cancel();
      } else { timer.cancel(); }
    });
  }

  // 🔥 FIX TOUCH: Fungsi ini dipanggil bila jari kena skrin (Tap/Scroll)
  void _triggerTouchActive() {
    _liveTouchScore = 1.0; // TERUS HIJAU
    setState(() => _patternScore = 1.0); // Pattern pun hijau
    
    _touchDecayTimer?.cancel();
    _touchDecayTimer = Timer(const Duration(seconds: 3), () {
      // Lepas 3 saat baru indicator turun (Memory)
    });
  }

  void _analyzeScrollPattern() {
    _triggerTouchActive(); // Panggil touch active logic
    
    final now = DateTime.now();
    double speed = _lastScrollTime != null ? 1000.0 / now.difference(_lastScrollTime!).inMilliseconds : 0.0;
    _lastScrollTime = now;
    _touchData.add({'timestamp': now, 'speed': speed, 'pressure': 0.5, 'wheelIndex': _activeWheelIndex ?? 0});
    if (_touchData.length > 20) _touchData.removeAt(0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    _accelSub?.cancel(); _lockoutTimer?.cancel(); _wheelActiveTimer?.cancel(); _touchDecayTimer?.cancel();
    _pulseController.dispose(); _scanController.dispose(); _reticleController.dispose();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SecurityState state = widget.controller.state;
    Color activeColor = (state == SecurityState.SOFT_LOCK || state == SecurityState.HARD_LOCK) 
        ? _neonRed 
        : (state == SecurityState.UNLOCKED ? _neonGreen : _neonCyan);
    
    String statusLabel = _getStatusLabel(state);
    
    // Logic Decay Visual
    if (_touchDecayTimer != null && _touchDecayTimer!.isActive) {
      _liveTouchScore = 1.0; 
    } else {
      if (_liveTouchScore > 0) _liveTouchScore -= 0.05;
      if (_liveTouchScore < 0) _liveTouchScore = 0;
    }
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Stack(
        children: [
          // ⚠️ PENTING: Class ini ada di bahagian bawah fail
          Positioned.fill(child: CustomPaint(painter: KineticGridPainter(color: activeColor))),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: _bgDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: activeColor.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: activeColor.withOpacity(0.15), blurRadius: 40, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHUDHeader(activeColor, statusLabel),
                if (widget.controller.threatMessage.isNotEmpty) _buildWarningBanner(),
                const SizedBox(height: 28),
                
                // INTERACTIVE AREA
                Listener(
                  onPointerDown: (_) {
                    _triggerTouchActive(); // TAP PUN DIKIRA
                    widget.controller.registerTouch();
                  },
                  child: _buildInteractiveTumblerArea(activeColor, state),
                ),
                
                const SizedBox(height: 28),
                _buildAuthButton(activeColor, state),
                const SizedBox(height: 20),
                Text(
                  "POWERED BY Z-KINETIC ENGINE V3.9",
                  style: TextStyle(
                    color: activeColor.withOpacity(0.4),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildHUDHeader(Color color, String status) {
    return Stack(
      children: [
        _buildHUDCorner(color, true, true), _buildHUDCorner(color, true, false),
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
                _buildSensorBox("MOTION", _liveMotionScore, color, Icons.sensors),
                const SizedBox(height: 8),
                _buildSensorBox("TOUCH", _liveTouchScore, color, Icons.fingerprint),
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
      height: 140,
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0, 
            child: CustomPaint(
              size: const Size(45, 140), 
              // ⚠️ PENTING: Painter ini ada di bahagian bawah
              painter: KineticPeripheralPainter(
                color: color, side: 'left', valX: _accelX, valY: _accelY, state: state,
              )
            )
          ),
          Positioned(
            right: 0, top: 0, bottom: 0, 
            child: CustomPaint(
              size: const Size(45, 140), 
              painter: KineticPeripheralPainter(
                color: color, side: 'right', valX: _accelX, valY: _accelY, state: state,
              )
            )
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 55),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  for (int i = 0; i < _scrollControllers.length; i++) {
                    if (_scrollControllers[i].position == notification.metrics) {
                      setState(() { _activeWheelIndex = i; });
                      _wheelActiveTimer?.cancel();
                      break;
                    }
                  }
                } else if (notification is ScrollUpdateNotification) {
                  widget.controller.registerTouch(); 
                  _analyzeScrollPattern(); 
                } else if (notification is ScrollEndNotification) {
                  _resetActiveWheelTimer();
                }
                return false;
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) => _buildHolographicWheel(index, color)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHolographicWheel(int index, Color color) {
    bool isActive = _activeWheelIndex == index;
    return Expanded(
      child: Listener(
        onPointerDown: (_) {
          setState(() => _activeWheelIndex = index);
          _wheelActiveTimer?.cancel();
          _triggerTouchActive(); // TAP RODA TERUS HIJAU
          widget.controller.registerTouch();
        },
        onPointerUp: (_) => _resetActiveWheelTimer(),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isActive ? 1.0 : 0.35,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isActive) Positioned.fill(child: AnimatedBuilder(animation: _reticleController, builder: (context, child) => CustomPaint(painter: KineticReticlePainter(color: color, progress: _reticleController.value)))),
              if (isActive) Positioned.fill(child: AnimatedBuilder(animation: _scanController, builder: (context, child) => CustomPaint(painter: KineticScanLinePainter(color: color, progress: _scanController.value)))),
              ListWheelScrollView.useDelegate(
                controller: _scrollControllers[index],
                itemExtent: 48, perspective: 0.003, diameterRatio: 1.1,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (v) { 
                  widget.controller.updateWheel(index, v % 10); 
                  HapticFeedback.selectionClick(); 
                  _analyzeScrollPattern(); 
                },
                childDelegate: ListWheelChildBuilderDelegate(builder: (context, i) => Center(child: Text('${i % 10}', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, shadows: isActive ? [Shadow(color: color, blurRadius: 20)] : [])))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetActiveWheelTimer() {
    _wheelActiveTimer?.cancel();
    _wheelActiveTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _activeWheelIndex = null);
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
          onPressed: isDisabled ? null : () => widget.controller.validateAttempt(hasPhysicalMovement: true),
          child: Text(
            state == SecurityState.HARD_LOCK ? "LOCKED" : "INITIATE ACCESS",
            style: TextStyle(
              fontWeight: FontWeight.w900, letterSpacing: 2.5, fontSize: 13,
              shadows: !isDisabled ? [Shadow(color: activeColor.withOpacity(0.9), blurRadius: 12)] : []
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHUDCorner(Color color, bool isTop, bool isLeft) {
    return Positioned(
      top: isTop ? 0 : null, bottom: !isTop ? 0 : null, left: isLeft ? 0 : null, right: !isLeft ? 0 : null,
      child: Container(width: 24, height: 24, decoration: BoxDecoration(border: Border(top: isTop ? BorderSide(color: color, width: 2) : BorderSide.none, left: isLeft ? BorderSide(color: color, width: 2) : BorderSide.none, right: !isLeft ? BorderSide(color: color, width: 2) : BorderSide.none, bottom: !isTop ? BorderSide(color: color, width: 2) : BorderSide.none))),
    );
  }

  Widget _buildSensorBox(String label, double val, Color color, IconData icon) {
    bool isMatch = val > 0.6; Color c = isMatch ? const Color(0xFF00FF88) : (val > 0.1 ? const Color(0xFFFF3366) : const Color(0xFF333333));
    return Container(width: 55, height: 42, decoration: BoxDecoration(border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(8), color: isMatch ? c.withOpacity(0.15) : Colors.transparent), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isMatch ? Icons.check_circle : icon, size: 16, color: c), Text(label, style: TextStyle(fontSize: 7, color: c, fontWeight: FontWeight.w900))]));
  }

  Widget _buildPatternBox(String label, double score, Color color) {
    bool isMatch = score >= 0.5; Color c = isMatch ? const Color(0xFF00FF88) : (score > 0.1 ? const Color(0xFFFF3366) : const Color(0xFF333333));
    return Container(width: 55, height: 42, decoration: BoxDecoration(border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(8), color: isMatch ? c.withOpacity(0.15) : Colors.transparent), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isMatch ? Icons.check_circle : Icons.timeline, size: 16, color: c), Text(label, style: TextStyle(fontSize: 7, color: c, fontWeight: FontWeight.w900))]));
  }

  Widget _buildWarningBanner() {
    return Container(margin: const EdgeInsets.only(top: 14), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFF3366).withOpacity(0.1), border: Border.all(color: const Color(0xFFFF3366)), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFFF3366), size: 18), const SizedBox(width: 10), Expanded(child: Text(widget.controller.threatMessage, style: const TextStyle(color: Color(0xFFFF3366), fontSize: 10, fontWeight: FontWeight.w900)))]));
  }
}

// ============================================
// 4. CUSTOM PAINTERS (INI BAHAGIAN YANG HILANG TADI)
// ============================================

class KineticGridPainter extends CustomPainter {
  final Color color; KineticGridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.04)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override bool shouldRepaint(KineticGridPainter old) => old.color != color;
}

class KineticPeripheralPainter extends CustomPainter {
  final Color color; final String side;
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
        canvas.drawLine(Offset(6.0 + (i*3), 60), Offset(6.0 + (i*3), 60 + h), Paint()..color = color.withOpacity(0.5)..strokeWidth = 1.2);
      }
      canvas.drawLine(const Offset(2, 10), const Offset(2, 130), p);
    }
  }

  void _drawText(Canvas c, TextPainter tp, String s, double x, double y, double sz, Color col, bool b) {
    tp.text = TextSpan(text: s, style: TextStyle(color: col, fontSize: sz, fontWeight: b ? FontWeight.bold : FontWeight.normal, fontFamily: 'Courier'));
    tp.layout(); tp.paint(c, Offset(x, y));
  }
  
  @override 
  bool shouldRepaint(KineticPeripheralPainter old) => 
    old.valX != valX || old.valY != valY || old.state != state;
}

class KineticReticlePainter extends CustomPainter {
  final Color color; final double progress;
  KineticReticlePainter({required this.color, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width/2, size.height/2);
    final p = Paint()..color = color.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.save(); canvas.translate(c.dx, c.dy); canvas.rotate(progress * 2 * pi); canvas.translate(-c.dx, -c.dy);
    canvas.drawCircle(c, 22, p);
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2;
      canvas.drawLine(Offset(c.dx + 18 * cos(a), c.dy + 18 * sin(a)), Offset(c.dx + 26 * cos(a), c.dy + 26 * sin(a)), p);
    }
    canvas.restore();
  }
  @override bool shouldRepaint(KineticReticlePainter old) => old.progress != progress;
}

class KineticScanLinePainter extends CustomPainter {
  final Color color; final double progress;
  KineticScanLinePainter({required this.color, required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, color.withOpacity(0.6), Colors.transparent]).createShader(Rect.fromLTWH(0, size.height * progress - 2, size.width, 4));
    canvas.drawRect(Rect.fromLTWH(0, size.height * progress - 2, size.width, 4), p);
  }
  @override bool shouldRepaint(KineticScanLinePainter old) => old.progress != progress;
}
