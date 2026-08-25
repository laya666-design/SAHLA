import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBHpypQOAQnMmifFtJcX97Mnbrb8ORnd6U',
    appId: '1:994131871524:android:25fd653f1e6da976ea15b1',
    messagingSenderId: '994131871524',
    projectId: 'fakerni-b96c2',
    storageBucket: 'fakerni-b96c2.firebasestorage.app',
  );
}
