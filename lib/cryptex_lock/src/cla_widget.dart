/*
 * PROJECT: CryptexLock Security Suite
 * UI: AAA GAME GRAPHICS (PBR Texture Mapping)
 * ASSET REQUIRED: assets/images/metal_plate.jpg
 */

import 'dart:async';
import 'dart:ui'; // Perlu untuk lerpDouble
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

class _CryptexLockState extends State<CryptexLock> with TickerProviderStateMixin, WidgetsBindingObserver {
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  
  // UI Animation State
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  // Privacy Shield
  int? _activeWheelIndex;
  late List<FixedExtentScrollController> _scrollControllers;
  
  // Warna Gred Tentera
  final Color _colLocked = const Color(0xFF00FFFF); // Cyan Neon
  final Color _colFail = const Color(0xFFFF9800);   
  final Color _colJam = const Color(0xFFFF3333);    
  final Color _colUnlock = const Color(0xFF00E676); 
  final Color _colDead = const Color(0xFF616161);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScrollControllers();
    _initAnimations();
    _startListening();
    
    // Listen perubahan state dari Controller
    widget.controller.addListener(_handleControllerChange);
  }
  
  void _handleControllerChange() {
    if (widget.controller.state == SecurityState.UNLOCKED) {
      widget.onSuccess();
    } else if (widget.controller.state == SecurityState.HARD_LOCK) {
      widget.onJammed();
    }
    
    // Update Bar Motion secara LIVE
    if (mounted) {
       _animateScoreBar(widget.controller.motionConfidence);
    }
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
  
  void _initAnimations() {
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // Ultra-fast response (Turbo)
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (index) {
      int startVal = widget.controller.getInitialValue(index);
      return FixedExtentScrollController(initialItem: startVal);
    });
  }

  void _startListening() {
    _accelSub?.cancel();
    
    // SENSOR MOTION (Raw Feed)
    _accelSub = userAccelerometerEvents.listen((UserAccelerometerEvent e) {
      double rawMag = e.x.abs() + e.y.abs() + e.z.abs();
      widget.controller.registerShake(rawMag, e.x, e.y, e.z);
    });
  }
  
  void _animateScoreBar(double target) {
    if (!mounted) return;
    _progressAnimation = Tween<double>(
      begin: _progressController.value,
      end: target,
    ).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic));
    
    _progressController.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChange);
    _accelSub?.cancel();
    _progressController.dispose();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.heavyImpact(); // Bunyi berat besi
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return _buildStateUI(widget.controller.state);
      },
    );
  }

  Widget _buildStateUI(SecurityState state) {
    Color activeColor;
    String statusText;
    IconData statusIcon;
    bool isInputDisabled = false;

    if (state == SecurityState.LOCKED) {
       // Logic Text
       if (widget.controller.motionConfidence > 0.8) { 
         activeColor = _colUnlock;
         statusText = "MOTION: ACTIVE";
         statusIcon = Icons.graphic_eq;
       } else if (widget.controller.motionConfidence > 0.1) {
         activeColor = _colLocked;
         statusText = "SENSING...";
         statusIcon = Icons.sensors; 
       } else {
         activeColor = _colDead;
         statusText = "SECURE VAULT";
         statusIcon = Icons.lock_outline; 
       }
    } else if (state == SecurityState.VALIDATING) {
        activeColor = Colors.white;
        statusText = "VERIFYING...";
        statusIcon = Icons.cloud_sync;
        isInputDisabled = true;
    } else if (state == SecurityState.SOFT_LOCK) {
        activeColor = _colFail;
        statusText = "MISMATCH (${widget.controller.failedAttempts}/3)";
        statusIcon = Icons.warning_amber_rounded;
    } else if (state == SecurityState.HARD_LOCK) {
        activeColor = _colJam;
        statusText = "LOCKED (${widget.controller.remainingLockoutSeconds}s)";
        statusIcon = Icons.block;
        isInputDisabled = true;
    } else if (state == SecurityState.ROOT_WARNING) {
        return _buildSecurityWarningUI(); // K9 Watchdog UI
    } else { 
        activeColor = _colUnlock;
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
        boxShadow: [BoxShadow(color: activeColor.withOpacity(0.15), blurRadius: 25)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER STATUS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: activeColor, size: 18),
              const SizedBox(width: 10),
              Text(statusText, style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 25),
          
          // METERS (BAR + BOX)
          Row(
            children: [
              // 1. BAR MOTION (Expanded - Primary)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text("MOTION", style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                         Text("${(_progressAnimation.value * 100).toInt()}%", style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, fontSize: 10)),
                       ],
                     ),
                     const SizedBox(height: 6),
                     ClipRRect(
                       borderRadius: BorderRadius.circular(2),
                       child: LinearProgressIndicator(
                         value: _progressAnimation.value,
                         backgroundColor: Colors.grey[900],
                         color: activeColor,
                         minHeight: 6,
                       ),
                     ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              // 2. KOTAK TOUCH (Compact - Secondary)
              _buildTouchBox(widget.controller.touchConfidence),
            ],
          ),
          
          const SizedBox(height: 25),
          
          // WHEELS (HYPER-REALISM TEXTURE)
          SizedBox(
            height: 120,
            child: IgnorePointer(
              ignoring: isInputDisabled,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // Logic Touch Detection
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
          
          // UNLOCK BUTTON
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
  
  // WIDGET: KOTAK TOUCH CHECKBOX (Clean Look)
  Widget _buildTouchBox(double value) {
    bool isVerified = value > 0.5;
    Color boxColor = isVerified ? _colUnlock : Colors.grey[900]!;
    Color iconColor = isVerified ? Colors.black : Colors.grey[700]!;
    
    return Column(
      children: [
        Text("TOUCH", style: TextStyle(color: Colors.grey[600], fontSize: 9)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isVerified ? _colUnlock : Colors.grey[800]!),
            boxShadow: isVerified ? [BoxShadow(color: _colUnlock.withOpacity(0.4), blurRadius: 8)] : [],
          ),
          child: Center(
            child: Icon(Icons.check, size: 18, color: iconColor),
          ),
        ),
      ],
    );
  }
  
  // 🔥 WIDGET UTAMA: RODA BESI (TEXTURE MAPPED)
  Widget _buildPrivacyWheel(int index, Color color, bool disabled) {
    final double opacity = (_activeWheelIndex != null) ? 1.0 : 0.6;
    
    return Container(
      width: 60, 
      decoration: BoxDecoration(
        color: const Color(0xFF050505), // Latar belakang gelap
        // Frame luar (Housing) supaya nampak tertanam
        border: Border.symmetric(vertical: BorderSide(color: Colors.black, width: 2)),
        boxShadow: [
           BoxShadow(color: Colors.black, blurRadius: 10, spreadRadius: 2, offset: Offset(0, 0)),
        ]
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: disabled ? 0.3 : opacity,
        child: ListWheelScrollView.useDelegate(
          controller: _scrollControllers[index],
          itemExtent: 70, // Jarak besar sikit untuk tekstur jelas
          perspective: 0.006,
          diameterRatio: 1.5, 
          physics: const FixedExtentScrollPhysics(), // SNAP PHYSICS
          useMagnifier: true,
          magnification: 1.2,
          onSelectedItemChanged: (val) {
             HapticFeedback.heavyImpact(); // Bunyi berat besi
             widget.controller.updateWheel(index, val % 10);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, i) {
              final num = i % 10;
              
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // 1. TEXTURE LAYER (GAMBAR ASET KAPTEN)
                  image: DecorationImage(
                    image: AssetImage('assets/images/metal_plate.jpg'), 
                    fit: BoxFit.cover,
                    // Gelapkan sikit texture supaya nombor jelas
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Container(
                  // 2. LIGHTING LAYER (Gradient Silinder)
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.9), // Bayang Atas
                        Colors.transparent,            // Tengah
                        Colors.white.withOpacity(0.15), // Highlight Kilat
                        Colors.transparent,            // Tengah
                        Colors.black.withOpacity(0.9), // Bayang Bawah
                      ],
                      stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                    ),
                  ),
                  child: Center(
                    // 3. NOMBOR (ENGRAVED / PAHAT)
                    child: Text(
                      '$num',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Roboto', 
                        // Nombor 0 Merah Menyala (Danger), Lain Putih Kusam
                        color: (num == 0) 
                            ? const Color(0xFFFF3333).withOpacity(0.95) 
                            : const Color(0xFFEEEEEE).withOpacity(0.9),
                        shadows: [
                          // Drop shadow tebal
                          BoxShadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
                          // Glow merah jika nombor 0
                          if (num == 0) BoxShadow(color: Colors.red.withOpacity(0.6), blurRadius: 15, spreadRadius: 2),
                        ]
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // K9 WATCHDOG UI
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
