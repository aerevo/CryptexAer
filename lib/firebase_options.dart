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
    apiKey: 'GANTI_DENGAN_API_KEY_ANDROID', // Contoh: AIzaSyDOCab...
    appId: 'GANTI_DENGAN_APP_ID_ANDROID',   // Contoh: 1:123456789:android:abcdef...
    messagingSenderId: 'GANTI_DENGAN_SENDER_ID', // Contoh: 123456789
    projectId: 'z-kinetic-pro', // Pastikan ID projek tuan betul
    storageBucket: 'z-kinetic-pro.appspot.com',
  );

  // 🍎 CONFIG UNTUK iOS
  // Buka Firebase Console > Project Settings > General > Your Apps (iOS)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'GANTI_DENGAN_API_KEY_IOS',
    appId: 'GANTI_DENGAN_APP_ID_IOS',
    messagingSenderId: 'GANTI_DENGAN_SENDER_ID',
    projectId: 'z-kinetic-pro',
    storageBucket: 'z-kinetic-pro.appspot.com',
    iosBundleId: 'com.aer.zkinetic', // Pastikan Bundle ID sama dengan projek Tuan
  );
}
