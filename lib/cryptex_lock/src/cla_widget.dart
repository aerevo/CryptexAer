import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:sensors_plus/sensors_plus.dart';
import 'cla_controller.dart';
import 'cla_models.dart';

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
  
  // Privacy Shield
  int? _activeWheelIndex;
  late List<FixedExtentScrollController> _scrollControllers;
  
  // 🔥 COLOR PALETTE (MONO-CYAN)
  // Kita tak guna Hijau atau Kuning. Kita main dengan Brightness Cyan.
  final Color _colNeon = const Color(0xFF00FFFF); // Cyan Terang (Active/Unlock)
  final Color _colDim  = const Color(0xFF008B8B); // Cyan Gelap (Idle)
  final Color _colFail = const Color(0xFFFF9800);   
  final Color _colJam  = const Color(0xFFFF3333);    
  final Color _colDead = const Color(0xFF424242);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    _startListening();
    widget.controller.addListener(_handleControllerChange);
  }
  
  void _handleControllerChange() {
    if (widget.controller.state == SecurityState.UNLOCKED) {
      widget.onSuccess();
    } else if (widget.controller.state == SecurityState.HARD_LOCK) {
      widget.onJammed();
    }
    // Update UI setiap kali data sensor masuk (Direct Feed)
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _accelSub?.cancel();
      _accelSub = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_accelSub == null) {
        _startListening();
      }
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    _accelSub?.cancel();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.selectionClick(); 
  }

  @override
  Widget build(BuildContext context) {
    // Kita tak pakai AnimatedBuilder untuk root sebab kita guna setState direct
    return _buildStateUI(widget.controller.state);
  }

  Widget _buildStateUI(SecurityState state) {
    Color activeColor;
    Color boxColor; // Warna khas untuk kotak sensor
    String statusText;
    IconData statusIcon;
    bool isInputDisabled = false;

    // LOGIK WARNA MONO-CYAN
    if (state == SecurityState.LOCKED) {
       // Kalau Motion > 0.8 (Detection), UI jadi TERANG
       if (widget.controller.motionConfidence > 0.8) { 
         activeColor = _colNeon;
         statusText = "MOTION DETECTED";
         statusIcon = Icons.graphic_eq;
       } 
       // Kalau Sensing (0.1 - 0.8), UI jadi sederhana
       else if (widget.controller.motionConfidence > 0.1) {
         activeColor = _colNeon.withOpacity(0.8);
         statusText = "SENSING...";
         statusIcon = Icons.sensors; 
       } 
       // Kalau Idle, UI jadi malap (Cyan Gelap)
       else {
         activeColor = _colDim;
         statusText = "IDLE";
         statusIcon = Icons.lock_outline; 
       }
       boxColor = _colNeon; // Kotak sentiasa Neon
    } else if (state == SecurityState.VALIDATING) {
        activeColor = Colors.white;
        boxColor = Colors.white;
        statusText = "VERIFYING...";
        statusIcon = Icons.cloud_sync;
        isInputDisabled = true;
    } else if (state == SecurityState.SOFT_LOCK) {
        activeColor = _colFail;
        boxColor = _colFail;
        statusText = "MISMATCH (${widget.controller.failedAttempts}/3)";
        statusIcon = Icons.warning_amber_rounded;
    } else if (state == SecurityState.HARD_LOCK) {
        activeColor = _colJam;
        boxColor = _colJam;
        statusText = "LOCKED (${widget.controller.remainingLockoutSeconds}s)";
        statusIcon = Icons.block;
        isInputDisabled = true;
    } else if (state == SecurityState.ROOT_WARNING) {
        return _buildSecurityWarningUI(); 
    } else { 
        activeColor = _colNeon; // Unlock kekal Cyan (Tak tukar hijau)
        boxColor = _colNeon;
        statusText = "ACCESS GRANTED";
        statusIcon = Icons.lock_open;
        isInputDisabled = true;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: activeColor.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: activeColor, size: 18),
              const SizedBox(width: 10),
              Text(statusText, style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 25),
          
          // 🔥 DUA KOTAK SENSOR (KIRI & KANAN)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. MOTION SENSOR (3 Fasa)
              _buildMotionBox(widget.controller.motionConfidence, boxColor),
              
              // 2. BIO-THERMAL (Touch)
              _buildBioThermalBox(widget.controller.touchConfidence, boxColor),
            ],
          ),
          
          const SizedBox(height: 25),
          
          // WHEELS
          SizedBox(
            height: 120,
            child: IgnorePointer(
              ignoring: isInputDisabled,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                     widget.controller.registerTouch(); 
                     if (_activeWheelIndex == null) {
                       setState(() => _activeWheelIndex = 1); 
                     }
                  } else if (notification is ScrollEndNotification) {
                     Future.delayed(const Duration(milliseconds: 500), () {
                       if (mounted) setState(() => _activeWheelIndex = null); 
                     });
                  }
                  return false;
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) => _buildPrivacyWheel(index, activeColor, isInputDisabled)),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 25),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isInputDisabled ? Colors.grey[900] : activeColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isInputDisabled ? null : () => widget.controller.validateAttempt(hasPhysicalMovement: true),
              child: Text(
                state == SecurityState.HARD_LOCK ? "LOCKED" : "AUTHENTICATE", 
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 🔥 WIDGET 1: MOTION SENSOR (SISTEM 3 FASA)
  Widget _buildMotionBox(double value, Color color) {
    IconData iconToShow;
    String label;
    bool isActive = false;

    if (value > 0.8) {
      // FASA 3: DETECTED (Tick)
      iconToShow = Icons.check_box;
      label = "DETECTED";
      isActive = true;
    } else if (value > 0.1) {
      // FASA 2: SENSING (Dot)
      // Kita guna icon bulat kecil dalam kotak
      iconToShow = Icons.radio_button_checked; 
      label = "SENSING";
      isActive = true;
    } else {
      // FASA 1: IDLE (Kosong)
      iconToShow = Icons.check_box_outline_blank;
      label = "MOTION";
      isActive = false;
    }

    return Column(
      children: [
        Text(label, style: TextStyle(color: isActive ? color : Colors.grey[600], fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 100), // Laju
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isActive ? color : Colors.grey[800]!),
            boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)] : [],
          ),
          child: Center(
            child: Icon(iconToShow, size: 24, color: isActive ? color : Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  // 🔥 WIDGET 2: BIO-THERMAL (SISTEM TOUCH)
  Widget _buildBioThermalBox(double value, Color color) {
    bool isVerified = value > 0.5;
    
    return Column(
      children: [
        // TUKAR NAMA JADI "BIO-THERMAL" (Finger Heat)
        Text("BIO-THERMAL", style: TextStyle(color: isVerified ? color : Colors.grey[600], fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isVerified ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isVerified ? color : Colors.grey[800]!),
            boxShadow: isVerified ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)] : [],
          ),
          child: Center(
            // Icon Cap Jari Api
            child: Icon(
              isVerified ? Icons.local_fire_department : Icons.fingerprint, 
              size: 24, 
              color: isVerified ? color : Colors.grey[700]
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPrivacyWheel(int index, Color color, bool disabled) {
    final double opacity = (_activeWheelIndex != null) ? 1.0 : 0.15;
    return SizedBox(
      width: 45,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disabled ? 0.3 : opacity,
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
                child: Text(
                  '$num',
                  style: TextStyle(
                    color: (num == 0 ? Colors.redAccent : Colors.white),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      if (_activeWheelIndex != null) 
                        BoxShadow(color: color.withOpacity(0.8), blurRadius: 10)
                    ]
                  ),
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
        color: const Color(0xFF450A0A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _colJam, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.security, color: Colors.white, size: 48),
          const SizedBox(height: 20),
          const Text("K9 WATCHDOG ALERT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 12),
          const Text("Critical Security Breach Detected.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _colJam),
              onPressed: () => widget.controller.userAcceptsRisk(),
              child: const Text("ACKNOWLEDGE RISK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
