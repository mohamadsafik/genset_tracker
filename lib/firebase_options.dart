// ignore_for_file: unused_import

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyD2DTy7ra69F0t46jsImXDD2PFcFfpcR48',
      appId: '1:95857608729:android:672863db4961a88a7d8288',
      messagingSenderId: '95857608729',
      projectId: 'tes-1-9ee0c',
      databaseURL:
          'https://tes-1-9ee0c-default-rtdb.asia-southeast1.firebasedatabase.app',
      storageBucket: 'tes-1-9ee0c.firebasestorage.app',
    );
  }
}
