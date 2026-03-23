# Z-Kinetic Security SDK (Enterprise Grade) 🛡️

Z-Kinetic is a mobile-first, intelligent-grade biometric lock and anti-bot verification system. It replaces traditional, friction-heavy CAPTCHAs with a seamless, behavior-analyzing 3D cryptex wheel.

**Core Advantages:**
* **Mobile-First Behavioral Auth:** Specifically designed to analyze touchscreen micro-interactions (scroll velocity, device motion, touch latency).
* **Zero-Dependency Anti-Bot:** Does not rely on Google reCAPTCHA or third-party web tracking. 
* **100% Data Sovereignty:** Ready for On-Premise / Private Cloud deployment.
* **Zero-Secret Client Architecture:** No secret API keys are ever stored on the mobile client.

---

## 📦 1. Installation

If you are provided with the Flutter SDK package, add it to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Add the Z-Kinetic package (adjust path/git url accordingly)
  z_kinetic_sdk: ^4.2.0 
Run the following command to install the dependencies:

Bash

flutter pub get
Note: Z-Kinetic uses network-hosted assets to keep your app size incredibly small. No local images need to be configured in your assets folder.

🔒 2. Configuration (Initialization)
Z-Kinetic uses an immutable singleton pattern for enterprise-grade security. You must initialize the SDK before running your app.

IMPORTANT: Never put your Secret API Key in the frontend. You only need your public appId.

In your main.dart:

Dart

import 'package:flutter/material.dart';
import 'package:z_kinetic_sdk/z_kinetic_sdk.dart'; // Adjust import based on your setup

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Z-Kinetic Security Engine
  ZKinetic.initialize(
    appId: 'YOUR_PUBLIC_APP_ID', // e.g., 'BANK_ISLAM_01'
    // customServerUrl: '[https://your-private-cloud.com](https://your-private-cloud.com)' // Optional: For On-Premise clients
  );

  runApp(const MyApp());
}
🚀 3. Implementation
To trigger the Z-Kinetic verification (e.g., before processing a transaction, login, or ticket purchase), display the ZKineticWidgetProdukB.

First, instantiate the controller in your stateful widget:

Dart

final WidgetController _zkController = WidgetController();

@override
void dispose() {
  _zkController.dispose();
  super.dispose();
}
Then, show the widget:

Dart

// Example: Displaying it inside a Stack or Dialog
if (_showSecurity)
  Positioned.fill(
    child: ZKineticWidgetProdukB(
      controller: _zkController,
      onComplete: (bool success) {
        setState(() => _showSecurity = false);
        if (success) {
          // ✅ Verification Passed - Proceed with secure action
          processTransaction();
        } else {
          // ❌ Tamper / Bot Detected - Block action
          showAccessDenied();
        }
      },
      onCancel: () {
        setState(() => _showSecurity = false);
      },
    ),
  ),
⚙️ 4. Android Requirements
Ensure your app has internet access to perform the secure HMAC handshake and fetch the UI assets.

In android/app/src/main/AndroidManifest.xml, add this permission above the <application> tag:

XML

<uses-permission android:name="android.permission.INTERNET"/>
(Note: Anti-screenshot and secure window flags are handled automatically via platform channels by the SDK).

🛠️ Troubleshooting & Support
Error: "ZKinetic Error: Sila panggil ZKinetic.initialize() dahulu!"

Fix: You forgot to call ZKinetic.initialize(appId: ...) in your main.dart before triggering the widget.

Widget shows grey WiFi icon instead of the wheel

Fix: The device lacks internet connection, or the network is blocking the Z-Kinetic asset CDN.

Verification instantly fails

Fix: Ensure your appId is valid and your server-side subscription is active.

For enterprise support, documentation, or to obtain your appId, contact the Z-Kinetic Security Team.
