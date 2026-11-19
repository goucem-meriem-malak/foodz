import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Build-time configuration, passed with --dart-define-from-file=env.json.
/// These Firebase values are PUBLIC client identifiers (safe to ship, protected
/// by Firestore rules). Real secrets (service accounts) never go in the app.
abstract final class Env {
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String firebaseSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseAppIdAndroid = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const String firebaseAppIdWeb = String.fromEnvironment('FIREBASE_APP_ID_WEB');
  static const String firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  /// Address of the push server, for example
  /// https://PROJECT-REF.supabase.co/functions/v1/notify-order. Public, not a secret.
  static const String notifyUrl = String.fromEnvironment('NOTIFY_URL');

  /// Address of the photo upload function, for example
  /// https://PROJECT-REF.supabase.co/functions/v1/upload-image. Public, not a secret.
  static const String uploadUrl = String.fromEnvironment('UPLOAD_URL');

  /// Web and Windows share the Firebase "web app" registration.
  static String get _appId =>
      (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) ? firebaseAppIdWeb : firebaseAppIdAndroid;

  static bool get isConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      _appId.isNotEmpty;

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: _appId,
        messagingSenderId: firebaseSenderId,
        projectId: firebaseProjectId,
        authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
      );
}
