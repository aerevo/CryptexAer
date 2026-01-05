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

class _CryptexLockState extends State<CryptexLock> with TickerProviderStateMixin {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  
  double _lastX = 0, _lastY = 0, _lastZ = 0;
  
  // ABSORBER: Variable untuk simpan data yang dah "dilembutkan"
  double _smoothedMagnitude = 0.0; 
  
  // UI State for Smooth Animation
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  // Privacy Shield
  int? _activeWheelIndex;
  
  late List<FixedExtentScrollController> _scrollControllers;
  
  // Colors
  final Color _colLocked = const Color(0xFFFFD700); 
  final Color _colFail = const Color(0xFFFF9800);   
  final Color _colJam = const Color(0xFFFF3333);    
  final Color _colUnlock = const Color(0xFF00E676); 
  final Color _colDead = Colors.grey; 

  @override
  void initState() {
    super.initState();
    _initScrollControllers();
    _initAnimations();
    _startListening();
  }
  
  void _initAnimations() {
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Masa untuk jarum bergerak
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutQuad),
    );
  }

  void _initScrollControllers() {
    _scrollControllers = List.generate(5, (index) {
      int startVal = widget.controller.getInitialValue(index);
      return FixedExtentScrollController(initialItem: startVal);
    });
  }

  void _startListening() {
    // Kita set interval supaya tak "spam" (walaupun sensor laju)
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      double deltaX = (e.x - _lastX);
      double deltaY = (e.y - _lastY);
      double deltaZ = (e.z - _lastZ);
      
      double rawMagnitude = deltaX.abs() + deltaY.abs() + deltaZ.abs();
      _lastX = e.x; _lastY = e.y; _lastZ = e.z;

      // 🛑 TEKNIK ABSORBER (LOW-PASS FILTER)
      // Alpha 0.85 bermaksud: "Ambil 85% data lama, campur 15% data baru"
      // Ini mematikan 'spike' 2ms yang gila tu.
      _smoothedMagnitude = (_smoothedMagnitude * 0.85) + (rawMagnitude * 0.15);

      // Kita hantar data yang dah stabil sikit ke Controller
      // (Tapi hantar juga delta mentah untuk pengiraan entropy)
      widget.controller.registerShake(_smoothedMagnitude, deltaX, deltaY, deltaZ);
      
      // Update UI Bar hanya jika perubahan ketara (Jimat bateri)
      if ((_progressController.value - widget.controller.liveConfidence).abs() > 0.01) {
         _animateScoreBar(widget.controller.liveConfidence);
      }
    });
  }
  
  void _animateScoreBar(double target) {
    _progressAnimation = Tween<double>(
      begin: _progressController.value,
      end: target,
    ).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOut));
    
    _progressController.forward(from: 0);
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _progressController.dispose();
    for (var c in _scrollControllers) c.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        if (widget.controller.state == SecurityState.UNLOCKED) {
           Future.delayed(Duration.zero, widget.onSuccess);
        }
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
       // Confidence threshold 50% untuk nampak "Active"
       if (widget.controller.liveConfidence > 0.5) {
         activeColor = _colLocked;
         statusText = "BIO-LOCK: ACTIVE";
         statusIcon = Icons.fingerprint;
       } else {
         activeColor = _colDead;
         statusText = "STABILIZING...";
         statusIcon = Icons.waves; 
       }
    } else if (state == SecurityState.VALIDATING) {
        activeColor = Colors.white;
        statusText = "ANALYZING SIGNATURE...";
        statusIcon = Icons.radar;
        isInputDisabled = true;
    } else if (state == SecurityState.SOFT_LOCK) {
        activeColor = _colFail;
        statusText = "MISMATCH (${widget.controller.failedAttempts}/3)";
        statusIcon = Icons.warning_amber_rounded;
    } else if (state == SecurityState.HARD_LOCK) {
        activeColor = _colJam;
        statusText = "JAMMED (${widget.controller.remainingLockoutSeconds}s)";
        statusIcon = Icons.block;
        isInputDisabled = true;
    } else if (state == SecurityState.ROOT_WARNING) {
        return _buildLiabilityWaiverUI();
    } else { 
        activeColor = _colUnlock;
        statusText = "IDENTITY VERIFIED";
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: activeColor, size: 18),
              const SizedBox(width: 10),
              Text(statusText, style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 25),
          
          // BIO-SIGMA BAR
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text("BIO-SIGMA STABILITY", style: TextStyle(color: Colors.grey[600], fontSize: 9)),
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
                     minHeight: 3,
                   ),
                 ),
              ],
            ),
          ),
          
          const SizedBox(height: 25),
          
          // WHEELS
          SizedBox(
            height: 120,
            child: IgnorePointer(
              ignoring: isInputDisabled,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification || notification is ScrollUpdateNotification) {
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
            if (_activeWheelIndex == null) setState(() => _activeWheelIndex = 1);
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

  Widget _buildLiabilityWaiverUI() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.purple, width: 2), borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.security_update_warning, color: Colors.purple, size: 50),
          const SizedBox(height: 20),
          const Text("SYSTEM HARD-LOCKED", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Peranti anda tidak lagi dibenarkan mengakses perisian ini.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11)),
          if (widget.controller.threatMessage.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(top:10),
               child: Text(widget.controller.threatMessage, style: TextStyle(color: Colors.red, fontSize: 10)),
             ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => widget.controller.userAcceptsRisk(), child: const Text("FORCE OVERRIDE (LOGGED)"))
        ],
      ),
    );
  }
}
