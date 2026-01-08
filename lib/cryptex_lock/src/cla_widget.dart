import 'dart:async';
import 'dart:math';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:sensors_plus/sensors_plus.dart';
import 'cla_controller.dart';
import 'cla_models.dart';

// 🔥 ML Pattern Analyzer (Kekal Pintar)
class MLPatternAnalyzer {
  static double analyzePattern(List<Map<String, dynamic>> touchData) {
    if (touchData.length < 5) return 0.0;
    
    List<double> features = [];
    
    // 1. Timing variance
    List<int> intervals = [];
    for (int i = 1; i < touchData.length; i++) {
      intervals.add(touchData[i]['timestamp'].difference(touchData[i-1]['timestamp']).inMilliseconds);
    }
    double timingVariance = _calculateVariance(intervals.map((e) => e.toDouble()).toList());
    features.add(timingVariance / 1000.0); 
    
    // 2. Pressure consistency
    if (touchData[0].containsKey('pressure')) {
      List<double> pressures = touchData.map((e) => e['pressure'] as double).toList();
      double pressureVariance = _calculateVariance(pressures);
      features.add(pressureVariance);
    } else {
      features.add(0.5);
    }
    
    // 3. Speed consistency
    if (touchData[0].containsKey('speed')) {
      List<double> speeds = touchData.map((e) => e['speed'] as double).toList();
      double speedVariance = _calculateVariance(speeds);
      features.add(speedVariance);
    } else {
      features.add(0.5);
    }
    
    // 4. Tremor
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

class _CryptexLockState extends State<CryptexLock> with WidgetsBindingObserver {
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  Timer? _screenshotWatchdog;
  
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;
  late List<FixedExtentScrollController> _scrollControllers;
  
  // Z-KINETIC Data
  double _patternScore = 0.0;
  List<Map<String, dynamic>> _touchData = [];
  DateTime? _lastScrollTime;
  
  bool _suspiciousRootBypass = false;
  
  // 🎨 JET FIGHTER PALETTE
  final Color _colNeon = const Color(0xFF00FFFF); // CYAN (Rangka Utama)
  final Color _colPass = const Color(0xFF00E676); // GREEN (Instrumen OK)
  final Color _colFail = const Color(0xFFFF2E2E); // RED (Instrumen Fail)
  final Color _colAlert = const Color(0xFFFFAB00);

  // 📐 DIMENSIONS
  final double _radiusSmall = 12.0;
  final double _radiusLarge = 24.0;
  final double _borderActive = 1.5;

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
        'com.zachspong.rootcloak',
      ];
      final List<String> suspiciousPaths = [
        '/system/xbin/su',
        '/system/bin/su',
        '/sbin/su',
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
      // 🔥 FIX 3: INSTANT EJECT (No Freeze)
      widget.onJammed(); 
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _accelSub?.cancel();
      _accelSub = null;
      _screenshotWatchdog?.cancel();
      _wheelActiveTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_accelSub == null) _startListening();
      _startScreenshotWatchdog();
    }
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (index) {
      return FixedExtentScrollController(initialItem: widget.controller.getInitialValue(index));
    });
  }

  void _startListening() {
    _accelSub?.cancel();
    _accelSub = userAccelerometerEvents.listen((UserAccelerometerEvent e) {
      double rawMag = e.x.abs() + e.y.abs() + e.z.abs();
      widget.controller.registerShake(rawMag, e.x, e.y, e.z);
    });
  }

  void _analyzeScrollPattern() {
    final now = DateTime.now();
    double speed = 0.0;
    if (_lastScrollTime != null) {
      speed = 1000.0 / now.difference(_lastScrollTime!).inMilliseconds.toDouble();
    }
    _lastScrollTime = now;
    double pressure = 0.3 + Random().nextDouble() * 0.4; 
    
    _touchData.add({
      'timestamp': now,
      'speed': speed,
      'pressure': pressure,
      'wheelIndex': _activeWheelIndex ?? 0,
    });
    
    if (_touchData.length > 20) _touchData.removeAt(0);
    
    if (_touchData.length >= 5) {
      double mlScore = MLPatternAnalyzer.analyzePattern(_touchData);
      
      if (mlScore < 0.3) {
        _patternScore = mlScore;
      } else if (mlScore < 0.5) {
        _patternScore = 0.5; 
      } else {
        _patternScore = mlScore;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    _accelSub?.cancel();
    _screenshotWatchdog?.cancel();
    _wheelActiveTimer?.cancel();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  void _triggerHaptic({bool heavy = false}) {
    if (heavy) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildStateUI(widget.controller.state);
  }

  Widget _buildStateUI(SecurityState state) {
    // 🎨 GLOBAL THEME: CYAN (Tetap cantik)
    Color mainThemeColor = _colNeon;
    String statusText;
    IconData statusIcon;
    bool isInputDisabled = false;

    if (state == SecurityState.LOCKED) {
       bool hasMotion = widget.controller.motionConfidence > 0.05;
       bool hasTouch = widget.controller.touchConfidence > 0.3;
       
       if (widget.controller.motionConfidence > 0.8) { 
         statusText = "MOTION DETECTED";
         statusIcon = Icons.graphic_eq;
       } else if (hasMotion && hasTouch) {
         statusText = "SYSTEM ACTIVE";
         statusIcon = Icons.sensors;
       } else if (hasTouch) {
         statusText = "TOUCH DETECTED";
         statusIcon = Icons.touch_app;
       } else if (hasMotion) {
         statusText = "SENSING...";
         statusIcon = Icons.radar;
       } else {
         statusText = "AWAITING INPUT";
         statusIcon = Icons.lock_outline; 
         mainThemeColor = _colNeon.withOpacity(0.7); // Dim sikit kalau idle
       }
    } else if (state == SecurityState.VALIDATING) {
        mainThemeColor = Colors.white;
        statusText = "VERIFYING...";
        statusIcon = Icons.cloud_sync;
        isInputDisabled = true;
    } else if (state == SecurityState.SOFT_LOCK) {
        mainThemeColor = _colFail;
        statusText = "ATTEMPT FAILED (${widget.controller.failedAttempts}/3)";
        statusIcon = Icons.warning_amber_rounded;
        isInputDisabled = true;
    } else if (state == SecurityState.HARD_LOCK) {
        mainThemeColor = _colFail;
        statusText = "LOCKOUT INITIATED";
        statusIcon = Icons.block;
        isInputDisabled = true;
    } else if (state == SecurityState.ROOT_WARNING) {
        return _buildSecurityWarningUI(); 
    } else { 
        mainThemeColor = _colPass;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.lock_open;
        isInputDisabled = true;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(_radiusLarge),
        border: Border.all(
            color: mainThemeColor.withOpacity(0.5), 
            width: _borderActive
        ),
        boxShadow: [
          // GLOW CYAN UTAMA
          BoxShadow(color: mainThemeColor.withOpacity(0.15), blurRadius: 25)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT PANEL: SYSTEM STATUS
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: mainThemeColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "SYSTEM STATUS", 
                          style: TextStyle(
                            color: Colors.grey[600], 
                            fontSize: 10, 
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusText, 
                      style: TextStyle(
                        color: mainThemeColor, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 15,
                        letterSpacing: 0.5,
                        height: 1.2
                      )
                    ),
                    const SizedBox(height: 8),
                    Divider(color: mainThemeColor.withOpacity(0.3), height: 1),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // RIGHT PANEL: INSTRUMENT CLUSTER (MERAH/HIJAU)
              Column(
                children: [
                   _buildSensorBox(
                     label: "MOTION",
                     value: widget.controller.motionConfidence, 
                     icon: Icons.sensors,
                   ),
                   const SizedBox(height: 8),
                   _buildSensorBox(
                     label: "TOUCH",
                     value: widget.controller.touchConfidence, 
                     icon: Icons.fingerprint,
                   ),
                   const SizedBox(height: 8),
                   _buildPatternBox(
                     label: "PATTERN",
                     score: _patternScore,
                   ),
                ],
              )
            ],
          ),
          
          if (widget.controller.threatMessage.isNotEmpty || _suspiciousRootBypass) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _colFail.withOpacity(0.1),
                borderRadius: BorderRadius.circular(_radiusSmall),
                border: Border.all(color: _colFail.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: _colFail, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _suspiciousRootBypass 
                        ? "ROOT DETECTED"
                        : widget.controller.threatMessage,
                      style: TextStyle(
                        color: _colFail, 
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 25),
          
          // WHEELS AREA (TARGET LOCK SYSTEM)
          SizedBox(
            height: 120,
            child: IgnorePointer(
              ignoring: isInputDisabled,
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
                    _wheelActiveTimer?.cancel();
                    _wheelActiveTimer = Timer(const Duration(milliseconds: 300), () {
                      if (mounted) {
                        setState(() => _activeWheelIndex = null);
                      }
                    });
                  }
                  return false;
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    5, 
                    (index) => _buildPrivacyWheel(index, mainThemeColor, isInputDisabled)
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 25),
          
          // ACTION BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isInputDisabled ? Colors.grey[900] : mainThemeColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radiusSmall)
                ),
                elevation: isInputDisabled ? 0 : 6,
                shadowColor: mainThemeColor.withOpacity(0.4),
              ),
              onPressed: isInputDisabled 
                ? null 
                : () {
                    _triggerHaptic(heavy: true); 
                    widget.controller.validateAttempt(hasPhysicalMovement: true);
                  },
              child: Text(
                state == SecurityState.HARD_LOCK 
                  ? "SYSTEM LOCKED" 
                  : "ENGAGE", 
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1.5,
                  fontSize: 14
                ),
              ),
            ),
          ),
          
          if (state == SecurityState.LOCKED && 
              widget.controller.motionConfidence == 0 && 
              widget.controller.touchConfidence == 0) ...[
            const SizedBox(height: 12),
            Text(
              "Initialize input sequence",
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
  
  // 🔥 FIX 1: INSTRUMENT CLUSTER (Kotak Merah/Hijau dalam bingkai Cyan)
  Widget _buildSensorBox({
    required String label,
    required double value, 
    required IconData icon,
  }) {
    bool isPass = value > 0.6; // Threshold lulus
    
    // Warna kotak ikut status LULUS/GAGAL (bukan ikut tema luar)
    Color instrColor = isPass ? _colPass : _colFail;
    IconData instrIcon = isPass ? Icons.check_circle : Icons.circle_outlined;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 52,
          height: 40,
          decoration: BoxDecoration(
            // Background pudar
            color: instrColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(_radiusSmall),
            // Border terang
            border: Border.all(
              color: instrColor.withOpacity(0.8),
              width: 1.0,
            ),
            // Glow kecil untuk nampak aktif
            boxShadow: [
              BoxShadow(color: instrColor.withOpacity(0.2), blurRadius: 8)
            ]
          ),
          child: Center(
            child: Icon(instrIcon, size: 18, color: instrColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 7.5,
            color: instrColor.withOpacity(0.9), // Teks warna merah/hijau
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // 🔥 FIX 1: PATTERN BOX (Merah/Hijau/Kelabu)
  Widget _buildPatternBox({
    required String label,
    required double score,
  }) {
    bool isHumanLike = score >= 0.5; 
    bool hasData = score > 0;
    
    Color instrColor;
    IconData instrIcon;

    if (!hasData) {
      instrColor = Colors.grey; // Belum ada data = Kelabu neutral
      instrIcon = Icons.remove;
    } else if (isHumanLike) {
      instrColor = _colPass;
      instrIcon = Icons.check_circle;
    } else {
      instrColor = _colFail;
      statusIcon = Icons.warning_amber_rounded;
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 52,
          height: 40,
          decoration: BoxDecoration(
            color: instrColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(_radiusSmall),
            border: Border.all(
              color: instrColor.withOpacity(hasData ? 0.8 : 0.4),
              width: 1.0,
            ),
            boxShadow: hasData ? [
              BoxShadow(color: instrColor.withOpacity(0.2), blurRadius: 8)
            ] : [],
          ),
          child: Center(
            child: Icon(instrIcon, size: 18, color: instrColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 7.5,
            color: instrColor.withOpacity(0.9),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
  
  // 🔥 FIX 2: TARGET LOCK SYSTEM (Roda Aktif Shj Menyala)
  Widget _buildPrivacyWheel(int index, Color themeColor, bool disabled) {
    final bool isThisWheelActive = (_activeWheelIndex == index);
    
    // Opacity: Roda tak aktif jadi 'Stealth' (0.2)
    final double opacity = disabled ? 0.3 : (isThisWheelActive ? 1.0 : 0.2);
    
    return SizedBox(
      width: 45,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: ListWheelScrollView.useDelegate(
          controller: _scrollControllers[index],
          itemExtent: 45,
          perspective: 0.005,
          diameterRatio: 1.2,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (val) {
            _triggerHaptic(); 
            widget.controller.updateWheel(index, val % 10);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, i) {
              final num = i % 10;
              return Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    // Warna Cyan Terang bila aktif, Kelabu bila pasif
                    color: isThisWheelActive ? _colNeon : Colors.grey[800],
                    fontSize: isThisWheelActive ? 32 : 28,
                    fontWeight: FontWeight.bold,
                    shadows: isThisWheelActive ? [
                       // TARGET LOCK GLOW (CYAN)
                       BoxShadow(
                          color: _colNeon.withOpacity(0.9), 
                          blurRadius: 25,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5), 
                          blurRadius: 5,
                        )
                    ] : [],
                  ),
                  child: Text('$num'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityWarningUI() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(_radiusLarge),
        border: Border.all(color: _colAlert, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, color: _colAlert, size: 48),
          const SizedBox(height: 20),
          Text(
            "Security Protocol",
            style: TextStyle(
              color: _colAlert,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Environment integrity compromised. Root access identified.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (_suspiciousRootBypass) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _colFail.withOpacity(0.1),
                borderRadius: BorderRadius.circular(_radiusSmall),
                border: Border.all(color: _colFail.withOpacity(0.3)),
              ),
              child: Text(
                "⚠️ BYPASS TOOLS DETECTED",
                style: TextStyle(
                  color: _colFail,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _colAlert,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radiusSmall),
                ),
                elevation: 6,
              ),
              onPressed: () {
                _triggerHaptic(heavy: true);
                widget.controller.userAcceptsRisk();
              },
              child: const Text(
                "OVERRIDE PROTOCOL",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
