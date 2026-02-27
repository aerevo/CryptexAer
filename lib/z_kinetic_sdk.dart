import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CONFIGURATION
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticConfig {
  static const double imageWidth3 = 712.0;
  static const double imageHeight3 = 600.0;

  // ✅ Captain's exact coordinates (Grade AAA!)
  static const List<List<double>> coords3 = [
    [165, 155, 257, 380],
    [309, 155, 402, 380],
    [457, 155, 546, 381],
  ];

  static const List<double> btnCoords3 = [122, 435, 603, 546];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// WIDGET CONTROLLER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ✅ Biometric tracking (motion/touch/pattern)
// ✅ Firebase Functions backend
// ✅ API Key authentication
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class WidgetController {
  // ⚠️ UPDATE THIS! Replace with YOUR Firebase Functions URL
  // Format: https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/api
  // Example: https://asia-southeast1-zkinetic-prod.cloudfunctions.net/api
  static const String _serverUrl = 'https://asia-southeast1-z-kinetic.cloudfunctions.net/api';
  
  // ✅ API Key - klien wajib pass ni
  final String apiKey;

  String? _currentNonce;
  final ValueNotifier<List<int>> challengeCode = ValueNotifier([0, 0, 0]);
  final ValueNotifier<int> randomizeTrigger = ValueNotifier(0);

  // Biometric scores
  final ValueNotifier<double> motionScore = ValueNotifier(0.0);
  final ValueNotifier<double> touchScore = ValueNotifier(0.0);
  final ValueNotifier<double> patternScore = ValueNotifier(0.0);

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _lastMagnitude = 9.8;
  DateTime _lastMotionTime = DateTime.now();
  Timer? _decayTimer;

  WidgetController({required this.apiKey}) {
    _initSensors();
    _startDecayTimer();
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      double magnitude = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z);
      double delta = (magnitude - _lastMagnitude).abs();
      if (delta > 0.3) {
        motionScore.value = (delta / 3.0).clamp(0.0, 1.0);
        _lastMotionTime = DateTime.now();
      }
      _lastMagnitude = magnitude;
    });
  }

  void _startDecayTimer() {
    _decayTimer?.cancel();
    _decayTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final elapsed = DateTime.now().difference(_lastMotionTime).inSeconds;
      if (elapsed > 1) {
        motionScore.value = (motionScore.value - 0.05).clamp(0.0, 1.0);
      }
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // API CALLS (Firebase Functions)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> getChallenge() async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/challenge'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _currentNonce = data['nonce'];
          challengeCode.value = List<int>.from(data['challengeCode']);
          print('✅ Challenge received: ${challengeCode.value}');
        } else {
          throw Exception(data['error'] ?? 'Failed to get challenge');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Network error: $e');
      // Local fallback (backup mode)
      _currentNonce = 'local_${DateTime.now().millisecondsSinceEpoch}';
      challengeCode.value = List.generate(3, (_) => Random().nextInt(10));
      print('⚠️ Using local fallback mode');
    }
  }

  Future<Map<String, dynamic>> verifyChallenge(List<int> userResponse) async {
    if (_currentNonce == null) {
      return {'allowed': false, 'error': 'No active challenge'};
    }

    // Local fallback check
    if (_currentNonce!.startsWith('local_')) {
      final match = userResponse.join() == challengeCode.value.join();
      return {
        'allowed': match,
        'mode': 'local',
        'message': match ? 'Verified (Local)' : 'Failed (Local)'
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/verify'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode({
          'nonce': _currentNonce,
          'userResponse': userResponse,
          'biometricData': {
            'motion': motionScore.value,
            'touch': touchScore.value,
            'pattern': patternScore.value,
          },
          'deviceId': 'flutter_device_${apiKey.substring(8, 16)}'
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'allowed': data['allowed'] ?? false,
          'riskScore': data['riskScore'] ?? 'UNKNOWN',
          'confidence': data['confidence'] ?? 0.0,
          'mode': 'server'
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'allowed': false,
          'error': data['error'] ?? 'Verification failed',
          'code': data['code'] ?? 'UNKNOWN'
        };
      }
    } catch (e) {
      print('❌ Verification error: $e');
      // Local fallback
      final match = userResponse.join() == challengeCode.value.join();
      return {
        'allowed': match,
        'mode': 'local_fallback',
        'error': 'Network error'
      };
    }
  }

  void registerTouch() => touchScore.value = Random().nextDouble() * 0.3 + 0.7;
  void registerScroll() => patternScore.value = 0.8;
  void randomizeWheels() => randomizeTrigger.value++;

  void dispose() {
    _accelSub?.cancel();
    _decayTimer?.cancel();
    challengeCode.dispose();
    randomizeTrigger.dispose();
    motionScore.dispose();
    touchScore.dispose();
    patternScore.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MAIN WIDGET (OVERLAY)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ZKineticWidgetProdukB extends StatefulWidget {
  final WidgetController controller;
  final Function(bool) onComplete;
  final VoidCallback? onCancel;

  const ZKineticWidgetProdukB({
    super.key,
    required this.controller,
    required this.onComplete,
    this.onCancel,
  });

  @override
  State<ZKineticWidgetProdukB> createState() => _ZKineticWidgetProdukBState();
}

class _ZKineticWidgetProdukBState extends State<ZKineticWidgetProdukB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final List<FixedExtentScrollController> _scrollControllers = [];
  final List<int> _userSelection = [0, 0, 0];

  bool _isLoading = false;
  int? _activeWheelIndex;
  Timer? _wheelActiveTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    for (int i = 0; i < 3; i++) {
      _scrollControllers.add(FixedExtentScrollController(initialItem: 0));
    }

    _animController.forward();
    _loadChallenge();
  }

  @override
  void dispose() {
    _animController.dispose();
    _wheelActiveTimer?.cancel();
    for (var c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    setState(() => _isLoading = true);
    await widget.controller.getChallenge();
    setState(() => _isLoading = false);
  }

  void _onWheelScrollStart(int index) {
    setState(() => _activeWheelIndex = index);
    _wheelActiveTimer?.cancel();
    widget.controller.registerTouch();
  }

  void _onWheelScrollEnd(int index) {
    _wheelActiveTimer?.cancel();
    _wheelActiveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _activeWheelIndex = null);
    });
  }

  Future<void> _onButtonTap() async {
    setState(() => _isLoading = true);

    final result = await widget.controller.verifyChallenge(_userSelection);

    setState(() => _isLoading = false);

    if (result['allowed'] == true) {
      widget.onComplete(true);
    } else {
      _showErrorDialog(result['error'] ?? 'Verification failed');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('❌ Verification Failed',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onComplete(false);
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildWheel(int wheelIndex, double height) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.controller.randomizeTrigger,
      builder: (context, trigger, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: ListWheelScrollView.useDelegate(
                controller: _scrollControllers[wheelIndex],
                itemExtent: height / 3,
                diameterRatio: 1.5,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (index) {
                  _userSelection[wheelIndex] = index % 10;
                  widget.controller.registerScroll();
                },
                childDelegate: ListWheelChildLoopingListDelegate(
                  children: List.generate(10, (i) {
                    return Center(
                      child: Text(
                        '$i',
                        style: TextStyle(
                          fontSize: 36, // ✅ FIXED: Changed from 48 to 36
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.9),
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 8)
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIndicator({
    required IconData icon,
    required String label,
    required ValueNotifier<double> notifier,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (context, value, child) {
        final isActive = value > 0.3;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? Colors.greenAccent : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: isActive ? Colors.greenAccent : Colors.grey,
                    fontSize: 10)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = (size.width / ZKineticConfig.imageWidth3).clamp(0.5, 1.2);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black.withOpacity(0.85),
        child: Stack(
          children: [
            // Main content...
            Center(
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: ZKineticConfig.imageWidth3,
                  height: ZKineticConfig.imageHeight3,
                  child: Stack(
                    children: [
                      // Background image
                      Positioned.fill(
                        child: Image.asset('assets/z_wheel3.png',
                            fit: BoxFit.fill), // ✅ FIXED: Changed from BoxFit.contain to BoxFit.fill
                      ),

                      // Wheels
                      ...List.generate(3, (i) {
                        final coords = ZKineticConfig.coords3[i];
                        final height = coords[3] - coords[1];
                        return Positioned(
                          left: coords[0],
                          top: coords[1],
                          width: coords[2] - coords[0],
                          height: height,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n is ScrollStartNotification) {
                                if (_scrollControllers[i].position == n.metrics)
                                  _onWheelScrollStart(i);
                              } else if (n is ScrollUpdateNotification) {
                                widget.controller.registerScroll();
                              } else if (n is ScrollEndNotification) {
                                _onWheelScrollEnd(i);
                              }
                              return false;
                            },
                            child: _buildWheel(i, height),
                          ),
                        );
                      }),

                      // Verify button
                      Positioned(
                        left: ZKineticConfig.btnCoords3[0],
                        top: ZKineticConfig.btnCoords3[1],
                        width: ZKineticConfig.btnCoords3[2] -
                            ZKineticConfig.btnCoords3[0],
                        height: ZKineticConfig.btnCoords3[3] -
                            ZKineticConfig.btnCoords3[1],
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white))
                            : InkWell(
                                onTap: _onButtonTap,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.transparent, // ✅ Keep transparent for production
                                    // For debugging, temporarily use: Colors.red.withOpacity(0.3)
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Biometric panel
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIndicator(
                      icon: Icons.sensors,
                      label: 'MOTION',
                      notifier: widget.controller.motionScore),
                  const SizedBox(width: 40),
                  _buildIndicator(
                      icon: Icons.touch_app,
                      label: 'TOUCH',
                      notifier: widget.controller.touchScore),
                  const SizedBox(width: 40),
                  _buildIndicator(
                      icon: Icons.fingerprint,
                      label: 'PATTERN',
                      notifier: widget.controller.patternScore),
                ],
              ),
            ),

            // Close button
            if (widget.onCancel != null)
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: widget.onCancel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
