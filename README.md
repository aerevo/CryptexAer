============================================================
  Z-KINETIC SECURITY WIDGET - INSTALLATION GUIDE
  Version 1.0 | Grade AAA
============================================================

WHAT YOU RECEIVE:
  ✅ z_kinetic_sdk.dart   (Security Engine)
  ✅ assets/z_wheel3.png  (Required Image)
  ✅ README.txt           (This file)

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

  In your StatefulWidget:

    bool _showSecurity = false;

    // Initialize controller (ONE LINE!)
    final WidgetController _controller = WidgetController();

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
                // e.g. process payment, open door, etc.
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

  To trigger the security check:

    ElevatedButton(
      onPressed: () => setState(() => _showSecurity = true),
      child: Text('BUY NOW'),
    )

============================================================
FULL EXAMPLE (main.dart)
============================================================

  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'z_kinetic_sdk.dart';

  void main() {
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(const MyApp());
  }

  class MyApp extends StatelessWidget {
    const MyApp({super.key});
    @override
    Widget build(BuildContext context) {
      return MaterialApp(home: const MyHomePage());
    }
  }

  class MyHomePage extends StatefulWidget {
    const MyHomePage({super.key});
    @override
    State<MyHomePage> createState() => _MyHomePageState();
  }

  class _MyHomePageState extends State<MyHomePage> {
    bool _showSecurity = false;
    final WidgetController _controller = WidgetController();

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: Stack(
          children: [
            Center(
              child: ElevatedButton(
                onPressed: () => setState(() => _showSecurity = true),
                child: const Text('BUY TICKET'),
              ),
            ),
            if (_showSecurity)
              ZKineticWidgetProdukB(
                controller: _controller,
                onComplete: (success) {
                  setState(() => _showSecurity = false);
                  if (success) {
                    // Your success action here
                  }
                },
                onCancel: () => setState(() => _showSecurity = false),
              ),
          ],
        ),
      );
    }
  }

============================================================
TROUBLESHOOTING
============================================================

  ❌ Red box appears (image error)
     → Make sure z_wheel3.png is in assets/ folder
     → Make sure pubspec.yaml has assets declaration

  ❌ Widget shows "..." forever
     → Check internet connection
     → Make sure INTERNET permission is added (Android)

  ❌ Build error: package not found
     → Run: flutter pub get

  ❌ Sensors not working on emulator
     → Test on real device only

============================================================
SUPPORT
============================================================

  This SDK connects to Z-Kinetic servers automatically.
  No configuration needed.
  
  Contact your Z-Kinetic representative for support.

============================================================
