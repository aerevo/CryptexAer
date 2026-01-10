import 'package:flutter/material.dart';
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptexAer Bio-Sigma',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: Colors.amber,
      ),
      home: const LockScreen(),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;

  @override
  void initState() {
    super.initState();
    
    // ═══════════════════════════════════════════════════════
    // PRODUCTION CONFIGURATION
    // ═══════════════════════════════════════════════════════
    _controller = ClaController(
      const ClaConfig(
        // Your secret code
        secret: [1, 7, 3, 9, 2],
        
        // ───────────────────────────────────────────────────
        // SECURITY LEVEL: Choose one
        // ───────────────────────────────────────────────────
        
        // DEVELOPMENT (Lenient - for testing)
        // minSolveTime: Duration(milliseconds: 1500),
        // minShake: 0.08,
        // thresholdAmount: 0.7,
        // maxAttempts: 5,
        
        // BALANCED (Recommended for production)
        minSolveTime: Duration(seconds: 2),
        minShake: 0.12,
        thresholdAmount: 0.85,
        maxAttempts: 3,
        
        // MAXIMUM (Bank-grade security - very strict)
        // minSolveTime: Duration(milliseconds: 2500),
        // minShake: 0.15,
        // thresholdAmount: 1.0,
        // maxAttempts: 3,
        
        // ───────────────────────────────────────────────────
        // LOCKOUT & COOLDOWN
        // ───────────────────────────────────────────────────
        jamCooldown: Duration(seconds: 30),      // Hard lockout duration
        softLockCooldown: Duration(seconds: 3),  // Between failed attempts
        
        // ───────────────────────────────────────────────────
        // BOT DETECTION
        // ───────────────────────────────────────────────────
        botDetectionSensitivity: 0.4,  // 0.0 = off, 1.0 = maximum
        enableSensors: true,            // Require motion sensors
        
        // ───────────────────────────────────────────────────
        // OPTIONAL: Server-side validation (future feature)
        // ───────────────────────────────────────────────────
        // securityConfig: SecurityConfig.production(
        //   serverEndpoint: "https://your-api.com/verify",
        // ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text(
              "ACCESS GRANTED", 
              style: TextStyle(
                color: Colors.white, 
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "✓ Identity Confirmed: HUMAN",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            SizedBox(height: 6),
            Text(
              "✓ Biometric signature verified",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            SizedBox(height: 6),
            Text(
              "✓ Pattern analysis passed",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            SizedBox(height: 6),
            Text(
              "✓ Code authentication successful",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.userAcceptsRisk(); // Reset for demo
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24, 
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "ENTER VAULT",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onFail() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Access Denied",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _controller.threatMessage.isEmpty 
                        ? "Wrong code or biometric mismatch"
                        : _controller.threatMessage,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[900],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _onJammed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF7F1D1D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text(
              "SECURITY LOCKOUT", 
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Multiple failed authentication attempts detected.",
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "System locked to prevent brute-force attacks.",
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.timer, color: Colors.white60, size: 16),
                SizedBox(width: 8),
                Text(
                  "Please wait for cooldown period",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A1A2E),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyan.withOpacity(0.1),
                          Colors.cyan.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.cyan.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.fingerprint, 
                          size: 60, 
                          color: Colors.cyan.withOpacity(0.8),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "AER BIO-VAULT",
                          style: TextStyle(
                            fontSize: 26, 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 4,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Military-Grade Security Protocol",
                          style: TextStyle(
                            color: Colors.grey[500], 
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Main Widget
                  CryptexLock(
                    controller: _controller,
                    onSuccess: _onSuccess,
                    onFail: _onFail,
                    onJammed: _onJammed,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Footer
                  Column(
                    children: [
                      Text(
                        "POWERED BY Z-KINETIC ENGINE V5.0",
                        style: TextStyle(
                          color: Colors.grey[800], 
                          fontSize: 9,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield, 
                            size: 12, 
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Production Ready • Optimized • Secure",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
