import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuration helper for Firebase initialization
class FirebaseConfig {
  /// Initialize Firebase Core for iOS & Android
  ///
  /// Firebase has no web configuration in this project yet (no
  /// `firebase_options.dart`), so it is skipped on web to avoid a crash.
  static Future<void> initialize() async {
    if (kIsWeb) {
      if (kDebugMode) {
        print('Firebase skipped on web (no web config present).');
      }
      return;
    }

    // Note: On Android & iOS, Firebase reads configuration from:
    // - android/app/google-services.json
    // - ios/Runner/GoogleService-Info.plist
    try {
      await Firebase.initializeApp();
      if (kDebugMode) {
        print('Firebase initialized successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Firebase initialization notice: $e');
        print('Ensure google-services.json (Android) / GoogleService-Info.plist (iOS) are placed in respective folders.');
      }
    }
  }
}
