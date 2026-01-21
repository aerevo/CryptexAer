// File: lib/firebase_options.dart
// ⚠️ ARAHAN: Gantikan nilai 'apiKey', 'appId', dan 'messagingSenderId' 
// dengan data sebenar dari Firebase Console > Project Settings.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase App.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // 🤖 CONFIG UNTUK ANDROID
  // Buka Firebase Console > Project Settings > General > Your Apps (Android)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA495TYtOEWdeBeNOyuSgsU0TsO3-_fy-E', // ✅ Key Universal Tuan
    appId: '1:55621733629:android:ef51c1276ef226b0408294', // ✅ ID Android Tuan
    messagingSenderId: '55621733629', // ✅ Project Number
    projectId: 'z-kinetic', // ✅ ID Projek Sebenar
    storageBucket: 'z-kinetic.appspot.com',
  );

  // 🍎 CONFIG UNTUK iOS
  // Buka Firebase Console > Project Settings > General > Your Apps (iOS)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA495TYtOEWdeBeNOyuSgsU0TsO3-_fy-E', // ✅ Key Universal Tuan
    appId: '1:55621733629:ios:98c57a2922abf197408294', // ✅ ID iOS Tuan
    messagingSenderId: '55621733629', // ✅ Project Number
    projectId: 'z-kinetic', // ✅ ID Projek Sebenar
    storageBucket: 'z-kinetic.appspot.com',
    iosBundleId: 'com.aer.zkinetic', // ✅ Bundle ID Tuan
  );
}
