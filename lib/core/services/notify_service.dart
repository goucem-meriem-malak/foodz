import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';

/// Asks the push server (Supabase Edge Function "notify-order") to alert the
/// right people about an order. The server reads the real order status itself,
/// so this only sends the order id and the caller's Firebase ID token.
/// Best effort: a failure never blocks the order flow.
class NotifyService {
  NotifyService(this._auth);
  final FirebaseAuth _auth;

  Future<void> orderChanged(String orderId) async {
    if (Env.notifyUrl.isEmpty) return;
    try {
      final token = await _auth.currentUser?.getIdToken();
      if (token == null) return;
      await http
          .post(
            Uri.parse(Env.notifyUrl),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({'orderId': orderId}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Push request skipped: $e');
    }
  }
}
