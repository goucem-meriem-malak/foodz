import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Stores this device's push token under users/{uid}/devices/{token}.
/// A small push server (Supabase Edge Function, added with the orders feature)
/// reads those tokens and sends the notification, so staff get alerts even when
/// the app is closed. Push is best effort: failures never block the app.
class PushService {
  PushService(this._db);
  final FirebaseFirestore _db;

  StreamSubscription<String>? _refreshSub;
  String? _token;

  /// Android and web only. Windows has no Firebase Messaging support.
  bool get supported => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  Future<void> register(String uid) async {
    if (!supported) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken(
        vapidKey: kIsWeb && Env.vapidKey.isNotEmpty ? Env.vapidKey : null,
      );
      if (token == null) return;
      _token = token;
      await _save(uid, token);
      await _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen((t) {
        _token = t;
        unawaited(_save(uid, t));
      });
    } catch (e) {
      debugPrint('Push registration skipped: $e');
    }
  }

  /// Called before sign-out so the next person on this device does not receive
  /// the previous user's notifications.
  Future<void> unregister(String uid) async {
    if (!supported) return;
    try {
      await _refreshSub?.cancel();
      _refreshSub = null;
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).collection('devices').doc(token).delete();
      }
      await FirebaseMessaging.instance.deleteToken();
      _token = null;
    } catch (e) {
      debugPrint('Push unregister skipped: $e');
    }
  }

  Future<void> _save(String uid, String token) =>
      _db.collection('users').doc(uid).collection('devices').doc(token).set({
        'platform': kIsWeb ? 'web' : 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
