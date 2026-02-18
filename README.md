============================================================
  Z-KINETIC SECURITY WIDGET - INSTALLATION GUIDE
  Version 1.0 | Grade AAA
============================================================

WHAT YOU RECEIVE:
  ✅ z_kinetic_sdk.dart   (Security Engine)
  ✅ assets/z_wheel3.png  (Required Image)
  ✅ README.txt           (This file)
  ✅ API Key              (Provided separately by Z-Kinetic)

============================================================
STEP 1: COPY FILES INTO YOUR PROJECT
============================================================

  Your Flutter project structure:

  my_app/
  ├── lib/
  │   ├── main.dart          ← Your existing file
  │   └── z_kinetic_sdk.dart ← COPY HERE
  ├── assets/
  │   └── z_wheel3.png       ← COPY HERE (create folder if needed)
  └── pubspec.yaml

============================================================
STEP 2: UPDATE pubspec.yaml
============================================================

  Add these dependencies:

    dependencies:
      flutter:
        sdk: flutter
      http: ^1.1.0
      sensors_plus: ^4.0.2

  Add the asset:

    flutter:
      assets:
        - assets/z_wheel3.png

  Then run:
    flutter pub get

============================================================
STEP 3: ADD INTERNET PERMISSION
============================================================

  Android → android/app/src/main/AndroidManifest.xml
  Add BEFORE <application tag:

    <uses-permission android:name="android.permission.INTERNET"/>

============================================================
STEP 4: USE IN YOUR APP
============================================================

  In your Dart file:

    import 'z_kinetic_sdk.dart';

  Initialize controller with your API Key:

    // ⚠️ IMPORTANT: Replace with YOUR API Key from Z-Kinetic
    final WidgetController _controller = WidgetController(
      apiKey: 'zk_live_YOUR_API_KEY_HERE',
    );

  In your build method:

    Stack(
      children: [
        // Your app content here...
        YourExistingUI(),

        // Z-Kinetic overlay
        if (_showSecurity)
          ZKineticWidgetProdukB(
            controller: _controller,
            onComplete: (bool success) {
              setState(() => _showSecurity = false);
              if (success) {
                // ✅ User verified - proceed with your action
              } else {
                // ❌ Bot detected - block action
              }
            },
            onCancel: () {
              setState(() => _showSecurity = false);
            },
          ),
      ],
    )

============================================================
API KEY INFORMATION
============================================================

  Your API Key is unique to your account.
  DO NOT share your API Key with anyone.
  DO NOT expose your API Key in public repositories.

  Your key determines:
  → Monthly verification limit
  → Subscription validity
  → Account status

  Contact Z-Kinetic support to:
  → Renew subscription
  → Upgrade plan
  → Report issues

============================================================
TROUBLESHOOTING
============================================================

  ❌ Error: "Invalid API Key"
     → Check your API Key is correct
     → Contact Z-Kinetic support

  ❌ Error: "Subscription expired"
     → Contact Z-Kinetic to renew

  ❌ Error: "Monthly limit reached"
     → Upgrade your plan

  ❌ Red box appears (image error)
     → Make sure z_wheel3.png is in assets/ folder
     → Check pubspec.yaml assets declaration

  ❌ Widget shows "..." forever
     → Check internet connection
     → Ensure INTERNET permission added (Android)

============================================================
