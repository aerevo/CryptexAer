// File: lib/firebase_options.dart
// 🛡️ Z-KINETIC SECURITY SUITE - FIREBASE CONFIGURATION
// Status: PRODUCTION READY ✅ | MULTI-PLATFORM SYNCED

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase App.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // 🤖 CONFIG ANDROID (Z-Kinetic Android)
  // Package Name: com.aer.zkinetic
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDej3jrmqkUYyCs8CYepwdbrlInSBNWt_w',
    appId: '1:55621733629:android:ef51c1276ef226b0408294',
    messagingSenderId: '55621733629',
    projectId: 'z-kinetic',
    storageBucket: 'z-kinetic.firebasestorage.app',
  );

  // 🍎 CONFIG iOS (Z-Kinetic iOS)
  // Bundle ID: com.aer.zkinetic
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDej3jrmqkUYyCs8CYepwdbrlInSBNWt_w',
    appId: '1:55621733629:ios:98c57a2922abf197408294',
    messagingSenderId: '55621733629',
    projectId: 'z-kinetic',
    storageBucket: 'z-kinetic.firebasestorage.app',
    iosBundleId: 'com.aer.zkinetic',
  );
}
