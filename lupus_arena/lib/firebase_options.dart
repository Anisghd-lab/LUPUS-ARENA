import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuration Firebase multi-plateforme (Web, Android, Desktop)
/// extraite des identifiants officiels de google-services.json
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDvR2rJGNha9DaP0VGuCQAvpCYQeMc7GGQ',
    appId: '1:1050312347949:web:9a78ceacb3b207d1dd03a4',
    messagingSenderId: '1050312347949',
    projectId: 'lupusarena',
    databaseURL:
        'https://lupusarena-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'lupusarena.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDvR2rJGNha9DaP0VGuCQAvpCYQeMc7GGQ',
    appId: '1:1050312347949:android:9a78ceacb3b207d1dd03a4',
    messagingSenderId: '1050312347949',
    projectId: 'lupusarena',
    databaseURL:
        'https://lupusarena-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'lupusarena.firebasestorage.app',
  );
}
