import 'package:firebase_core/firebase_core.dart';
import 'package:genset_tracker/firebase_options.dart';

class DefaultFirebaseConfig {
  static FirebaseOptions get platformOptions =>
      DefaultFirebaseOptions.currentPlatform;
}
