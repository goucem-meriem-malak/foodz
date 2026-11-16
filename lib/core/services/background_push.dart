import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Runs in its own isolate when a push arrives while the app is closed.
/// Notification messages (with a title and body) are shown by the system
/// without any Dart code; this handler exists so data-only messages also work.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: Env.firebaseOptions);
  }
  debugPrint('Background push received: ${message.messageId}');
}

void registerBackgroundPush() {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
}
