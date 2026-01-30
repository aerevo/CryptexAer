import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'cla_controller_v2.dart';
import 'cla_models.dart';

// ============================================
// 🔥 CRYPTEX LOCK WITH Z-KINETIC CORE STYLE FRAME
// Main Screen: Interactive with frame design
// Success Screen: BERJAYA with fitted text
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

// 🔥 SUCCESS SCREEN - BERJAYA!
class SuccessScreen extends StatelessWidget {
  final String message;

  const SuccessScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF607D8B),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // SUCCESS ICON
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 70,
                ),
              ),
              const SizedBox(height: 40),
              
              // BERJAYA TEXT (SAIZ BESAR & AUTO MUAT)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'BERJAYA!',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Colors.green[700],
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // SUBTITLE
              Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔥 FAIL DIALOG
class CompactFailDialog extends StatefulWidget {
  final String message;
  final Color accentColor;

  const CompactFailDialog({
    super.key,
    required this.message,
    required this.accentColor,
  });

  @override
  State<CompactFailDialog> createState() => _CompactFailDialogState();
}

class _CompactFailDialogState extends State<CompactFailDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );
    
    _controller.repeat(reverse: true);
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cancel,
                    color: widget.accentColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF263238),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥 MAIN WIDGET WITH Z-KINETIC CORE FRAME
class CryptexLock extends StatefulWidget {
  final ClaController controller;
  final VoidCallback? onSuccess;
  final VoidCallback? onFail;
  final VoidCallback? onJammed;

  const CryptexLock({
    super.key, 
    required this.controller,
    this.onSuccess,
    this.onFail,
    this.onJammed,
  });

  @override
  State<CryptexLock> createState() => _CryptexLockState();
}

class _CryptexLockState extends State<CryptexLock> with WidgetsBindingObserver, TickerProviderStateMixin {
  // 🔥 KOORDINAT RODA (626 x 471)
  static const List<List<double>> _wheelCoords = [
    [85, 133, 143, 286],
    [180, 132, 242, 285],
    [276, 133, 337, 282],
    [371, 132, 431, 282],
    [467, 130, 529, 285],
  ];

  // 🔥 KOORDINAT BUTTON "ACCESS"
  static const List<double> _buttonCoords = [150, 318, 472, 399];

  static const double _imageWidth = 626.0;
  static const double _imageHeight = 471.0;

  // State Management
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  Timer? _lockoutTimer;
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  late List<FixedExtentScrollController> _scrollControllers;

  final ValueNotifier<double> _motionScoreNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _touchScoreNotifier = ValueNotifier(0.0);

  double _patternScore = 0.0;
  bool _showTutorial = true;
  bool _showSuccessScreen = false;
  Timer? _tutorialHideTimer;
  Timer? _touchDecayTimer;

  double _lastX = 0, _lastY = 0, _lastZ = 0;
  final List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;

  late AnimationController _scanController;
  bool _isDisposed = false;

  // Colors - WARNA OREN UNTUK Z-KINETIC!
  final Color _primaryOrange = const Color(0xFFFF6F00); // WARNA OREN
  final Color _accentRed = const Color(0xFFD32F2F);
  final Color _successGreen = const Color(0xFF4CAF50);

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
    
    _scanController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

    _tutorialHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isDisposed) setState(() => _showTutorial = false);
    });
  }

  void _handleControllerChange() {
    if (_isDisposed) return;
    
    if (widget.controller.state == SecurityState.UNLOCKED) {
      setState(() {
        _showSuccessScreen = true;
      });
      
      widget.onSuccess?.call();
      
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_isDisposed) {
          setState(() {
            _showSuccessScreen = false;
          });
        }
      });
    } else if (widget.controller.state == SecurityState.SOFT_LOCK || widget.controller.state == SecurityState.HARD_LOCK) {
      if (widget.controller.threatMessage.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => CompactFailDialog(
            message: widget.controller.threatMessage,
            accentColor: _accentRed,
          ),
        );
      }
      
      if (widget.controller.state == SecurityState.SOFT_LOCK) {
        widget.onFail?.call();
      } else if (widget.controller.state == SecurityState.HARD_LOCK) {
        widget.onJammed?.call();
        
        _lockoutTimer = Timer(const Duration(seconds: 30), () {
          if (mounted) {
            _randomizeAllWheels();
          }
        });
      }
    }
    
    if (mounted && !_isDisposed) setState(() {});
  }

  void _onRandomizeTrigger() {
    if (widget.controller.shouldRandomizeWheels.value) {
      _randomizeAllWheels();
      widget.controller.shouldRandomizeWheels.value = false;
    }
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(
      5,
      (i) => FixedExtentScrollController(initialItem: 0),
    );
  }

  void _startListening() {
    _accelSub = userAccelerometerEventStream(samplingPeriod: const Duration(milliseconds: 100)).listen((event) {
      if (_isDisposed) return;
      
      double deltaX = (event.x - _lastX).abs();
      double deltaY = (event.y - _lastY).abs();
      double deltaZ = (event.z - _lastZ).abs();
      double totalMotion = deltaX + deltaY + deltaZ;
      
      if (totalMotion > 0.5) {
        _userInteracted();
        double clampedMotion = (totalMotion / 15.0).clamp(0.0, 1.0);
        _motionScoreNotifier.value = clampedMotion;
        
        _touchDecayTimer?.cancel();
        _touchDecayTimer = Timer(const Duration(seconds: 2), () {
          if (mounted && !_isDisposed) _motionScoreNotifier.value = 0.0;
        });
      }
      
      _lastX = event.x;
      _lastY = event.y;
      _lastZ = event.z;
    });
  }

  void _userInteracted() {
    if (_isDisposed) return;
    widget.controller.onInteractionStart();
    if (_showTutorial && mounted && !_isDisposed) {
      setState(() => _showTutorial = false);
      _tutorialHideTimer?.cancel();
    }
  }

  void _analyzeScrollPattern() {
    if (_isDisposed) return;
    
    final now = DateTime.now();
    if (_lastScrollTime != null) {
      final delta = now.difference(_lastScrollTime!).inMilliseconds;
      if (delta > 50 && delta < 500) {
        _patternScore = ((500 - delta) / 500).clamp(0.0, 1.0);
      }
    }
    _lastScrollTime = now;
    
    if (_activeWheelIndex != null) {
      double pressure = 0.8;
      _touchScoreNotifier.value = pressure;
      
      _touchDecayTimer?.cancel();
      _touchDecayTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && !_isDisposed) _touchScoreNotifier.value = 0.0;
      });
    }
    
    if (mounted && !_isDisposed) setState(() {});
  }

  void _randomizeAllWheels() {
    if (_isDisposed) return;
    final r = Random();
    for (var controller in _scrollControllers) {
      if (controller.hasClients) {
        controller.jumpToItem(r.nextInt(10) + (r.nextInt(10) * 10));
      }
    }
    if (mounted && !_isDisposed) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _accelSub?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _accelSub?.resume();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _accelSub?.cancel();
    _lockoutTimer?.cancel();
    _wheelActiveTimer?.cancel();
    _tutorialHideTimer?.cancel();
    _touchDecayTimer?.cancel();
    for (var c in _scrollControllers) {
      c.dispose();
    }
    _scanController.dispose();
    _motionScoreNotifier.dispose();
    _touchScoreNotifier.dispose();
    super.dispose();
  }

  void _handleAccessButton() {
    _userInteracted();
    HapticFeedback.mediumImpact();
    widget.controller.attemptUnlock();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccessScreen) {
      return const SuccessScreen(message: "Access granted!");
    }

    SecurityState state = widget.controller.state;
    Color activeColor = state == SecurityState.SOFT_LOCK || state == SecurityState.HARD_LOCK
        ? _accentRed
        : _primaryOrange;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ✅ 1) GANTI "Security Protect" → "Z-Kinetic Core" WARNA OREN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.security, color: _primaryOrange, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'Z-Kinetic Core',
                          style: TextStyle(
                            fontSize: 13,
                            color: _primaryOrange, // WARNA OREN
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ✅ 2) PADAM "This app looks safe" - TIADA LAGI!

                    // ✅ 3) PADAM gambar mangga & z kinetic verified - TIADA LAGI!

                    // Z-WHEEL SYSTEM (INTERACTIVE!)
                    Container(
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double screenWidth = constraints.maxWidth;
                          double aspectRatio = _imageWidth / _imageHeight;
                          double imageHeight = screenWidth / aspectRatio;
                          
                          return SizedBox(
                            width: screenWidth,
                            height: imageHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/z_wheel.png',
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                ..._buildWheelOverlays(screenWidth, imageHeight, activeColor, state),
                                _buildAccessButton(screenWidth, imageHeight, activeColor, state),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ 4) PADAM nombor kt bawah - TIADA CODE DISPLAY LAGI!

                    // ✅ 5) PADAM tanda √ dan "You can continue to access" - TIADA LAGI!

                    // ACCESS BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state == SecurityState.VALIDATING || state == SecurityState.HARD_LOCK
                            ? null
                            : _handleAccessButton,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD6E8F7),
                          foregroundColor: Colors.black87,
                          disabledBackgroundColor: Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Access',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // SENSOR INDICATORS
                    _buildSensorRow(activeColor),
                    
                    // WARNING BANNER
                    if (widget.controller.threatMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildWarningBanner(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // TUTORIAL OVERLAY
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

  Widget _buildAccessButton(double screenWidth, double screenHeight, Color activeColor, SecurityState state) {
    return const SizedBox.shrink();
  }

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

  Widget _buildAdvancedWheel(int index, double wheelHeight, Color activeColor) {
    bool isActive = _activeWheelIndex == index;
    double itemExtent = wheelHeight * 0.40;
    
    return GestureDetector(
      onTapDown: (_) {
        if (_isDisposed) return;
        setState(() => _activeWheelIndex = index);
        _wheelActiveTimer?.cancel();
        _userInteracted();
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          color: isActive ? _successGreen : Colors.grey[400],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isActive ? _successGreen : Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner() {
    return Container(
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
}

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
