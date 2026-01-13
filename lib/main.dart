// 📱 MAIN ENTRY POINT - "FULL FLOW: FORM -> WYSIWYS -> MATRIX LOCK"
// Status: ULTIMATE INTEGRATION
// Features: Transfer Form + Hacker Simulation + Neon Matrix Green Numbers

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cryptex_lock/src/cla_widget.dart';
import 'cryptex_lock/src/cla_controller.dart';
import 'cryptex_lock/src/cla_models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Kunci orientasi ke Portrait sahaja
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Z-KINETIC FINAL',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: Colors.blueAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      // 🔥 Mula dari Page Transfer (Isi Borang)
      home: const TransferPage(),
    );
  }
}

// ==========================================
// 1️⃣ PAGE PERTAMA: TRANSFER FORM (INPUT)
// ==========================================
class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: "5000.00");
  final _accountController = TextEditingController(text: "1234-5678-9012");
  final _nameController = TextEditingController(text: "ALI BIN AHMAD");

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _proceedToVerification({bool isHacked = false}) {
    if (_formKey.currentState!.validate()) {
      
      // Jika Mode Hacker, kita ubah data secara senyap! 😈
      final String displayAmount = isHacked ? "RM 99,999.00" : "RM ${_amountController.text}";
      final String displayName = isHacked ? "SCAMMER ACCOUNT" : _nameController.text.toUpperCase();
      final String transactionType = isHacked ? "⚠️ INTERCEPTED" : "TRANSFER FUNDS";

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LockScreen(
            transactionType: transactionType,
            amount: displayAmount,
            recipientName: displayName,
            accountNumber: _accountController.text,
            onUnlockSuccess: () {
              _showSuccessDialog(displayAmount, displayName);
            },
          ),
        ),
      );
    }
  }

  void _showSuccessDialog(String amount, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.green)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text("SUCCESS", style: TextStyle(color: Colors.green)),
          ],
        ),
        content: Text(
          "Transaction of $amount to $name has been authorized via Biometric Lock.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("DONE", style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Z-KINETIC BANKING")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.account_balance_wallet, size: 60, color: Colors.blueAccent),
                const SizedBox(height: 20),
                const Text(
                  "Secure Transfer",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // FORM INPUTS
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Amount (RM)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Account No.", border: OutlineInputBorder(), prefixIcon: Icon(Icons.credit_card)),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Recipient Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 40),

                // NORMAL BUTTON
                ElevatedButton(
                  onPressed: () => _proceedToVerification(isHacked: false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("PROCEED TO VERIFY", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                
                const SizedBox(height: 15),
                
                // HACKER BUTTON (Utk demo WYSIWYS)
                OutlinedButton.icon(
                  onPressed: () => _proceedToVerification(isHacked: true),
                  icon: const Icon(Icons.bug_report, color: Colors.red),
                  label: const Text("SIMULATE HACKER ATTACK", style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2️⃣ PAGE KEDUA: LOCK SCREEN (MATRIX STYLE)
// ==========================================
class LockScreen extends StatefulWidget {
  final String transactionType;
  final String amount;
  final String recipientName;
  final String accountNumber;
  final VoidCallback? onUnlockSuccess;

  const LockScreen({
    super.key,
    required this.transactionType,
    required this.amount,
    required this.recipientName,
    required this.accountNumber,
    this.onUnlockSuccess,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late ClaController _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    try {
      _controller = ClaController(
        const ClaConfig(
          // 🔑 PASSWORD RAHSIA
          secret: [1, 7, 3, 9, 2],
          // 🎯 SETTINGS
          minShake: 0.4, 
          botDetectionSensitivity: 0.25,  
          thresholdAmount: 0.25, 
          minSolveTime: Duration(milliseconds: 600),
          maxAttempts: 5,  
          jamCooldown: Duration(seconds: 10), 
          enableSensors: true,
          clientId: 'CRYPTER_FULL_FLOW',
          clientSecret: 'matrix_green_mode_active',
        ),
      );
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  void dispose() {
    if (_isInitialized) _controller.dispose();
    super.dispose();
  }

  void _onSuccess() {
    HapticFeedback.mediumImpact();
    if (widget.onUnlockSuccess != null) {
      widget.onUnlockSuccess!(); // Panggil callback ke page sebelum
    } else {
      Navigator.pop(context);
    }
  }

  void _onFail() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ WRONG PIN (${_controller.failedAttempts}/5)"), backgroundColor: Colors.red),
    );
  }

  void _onJammed() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("⛔ LOCKED FOR ${_controller.remainingLockoutSeconds}s"), backgroundColor: Colors.deepOrange),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("SECURITY CHECK"),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🎚️ BANNER (MATRIX STYLE)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF00).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00FF00), width: 1),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00FF00).withOpacity(0.2), blurRadius: 10),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, size: 24, color: Color(0xFF00FF00)),
                      SizedBox(width: 8),
                      Text("BIOMETRIC ACTIVE", style: TextStyle(color: Color(0xFF00FF00), fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 🚨 WYSIWYS ALERT BOX (DATA DARI FORM)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 2),
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 15)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                          SizedBox(width: 10),
                          Text("VERIFY TRANSACTION", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.transactionType, style: TextStyle(color: Colors.red.shade300, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, fontFamily: 'monospace')),
                            const SizedBox(height: 8),
                            // 🔥 DATA DINAMIK DARI FORM
                            Text(widget.amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            const SizedBox(height: 6),
                            Text("TO: ${widget.accountNumber}", style: TextStyle(color: Colors.red.shade300, fontSize: 13, fontFamily: 'monospace')),
                            Text(widget.recipientName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text("Cancel if details don't match", style: TextStyle(color: Colors.orange, fontSize: 11, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 🎮 CRYPTEX LOCK WIDGET
                CryptexLock(
                  controller: _controller,
                  onSuccess: _onSuccess,
                  onFail: _onFail,
                  onJammed: _onJammed,
                ),
                
                const SizedBox(height: 30),

                // 💡 TIPS BOX
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.green.withOpacity(0.1), Colors.blue.withOpacity(0.1)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tips_and_updates, color: Colors.yellow, size: 20),
                          SizedBox(width: 8),
                          Text("UNLOCK NATURALLY", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTip("🎯", "Target: 1-7-3-9-2"),
                      _buildTip("📱", "Angkat phone naturally"),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                
                // 📊 MATRIX DEBUG INFO (HIJAU NEON + GLOW)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00FF00).withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildMatrixDebugRow("TARGET", "1-7-3-9-2"),
                      const SizedBox(height: 8),
                      _buildMatrixDebugRow("ATTEMPTS", "${_controller.failedAttempts}/5"),
                      const SizedBox(height: 8),
                      _buildMatrixDebugRow("STATE", _controller.state.toString().split('.').last.toUpperCase()),
                      
                      const Divider(height: 20, color: Colors.white10),
                      
                      // Progress Bars
                      _buildMatrixBar("MOTION", _controller.motionConfidence),
                      const SizedBox(height: 10),
                      _buildMatrixBar("PATTERN", _controller.liveConfidence),
                      const SizedBox(height: 10),
                      _buildMatrixBar("TOUCH", _controller.touchConfidence),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }

  // 🔥 FUNGSI UTAMA: TEXT JADI HIJAU NEON (GLOW)
  Widget _buildMatrixDebugRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: const Color(0xFF00FF00).withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', letterSpacing: 1)),
        Text(value, style: const TextStyle(
          color: Color(0xFF00FF00), // ✅ Matrix Green
          fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1,
          shadows: [Shadow(color: Color(0xFF00FF00), blurRadius: 10)], // ✅ Glow
        )),
      ],
    );
  }

  // 🔥 FUNGSI BAR: NOMBOR PERATUSAN JADI HIJAU NEON
  Widget _buildMatrixBar(String label, double value) {
    final percentage = (value * 100).toStringAsFixed(0);
    final barColor = value >= 0.6 ? const Color(0xFF00FF00) : (value >= 0.3 ? const Color(0xFFFFFF00) : const Color(0xFFFF0000));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1)),
            Text("$percentage%", style: const TextStyle(
              color: Color(0xFF00FF00), // ✅ Force Matrix Green
              fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace',
              shadows: [Shadow(color: Color(0xFF00FF00), blurRadius: 8)],
            )),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(3), border: Border.all(color: barColor.withOpacity(0.3))),
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(decoration: BoxDecoration(color: barColor, boxShadow: [BoxShadow(color: barColor.withOpacity(0.6), blurRadius: 6)])),
          ),
        ),
      ],
    );
  }
}
