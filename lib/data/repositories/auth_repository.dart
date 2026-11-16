import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/push_service.dart';
import 'user_repository.dart';

class AuthRepository {
  AuthRepository(this._auth, this._users, this._push);

  final FirebaseAuth _auth;
  final UserRepository _users;
  final PushService _push;

  /// Google sign-in works on Android and web. Windows has no provider flow.
  bool get googleSupported => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  bool get isPasswordUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  /// Creates the Auth user, sends the verification email, then the profile.
  /// If the profile write fails, the app routes to "complete profile".
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String locale,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    try {
      await user.sendEmailVerification();
    } catch (e) {
      debugPrint('Verification email not sent: $e');
    }
    await _users.createProfile(
      uid: user.uid,
      name: name,
      phone: phone,
      email: email,
      locale: locale,
    );
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> resendVerification() async => _auth.currentUser?.sendEmailVerification();

  /// Reloads the user and refreshes the ID token, because the rules read the
  /// `email_verified` claim from the token.
  Future<bool> refreshVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _push.unregister(uid);
    await _auth.signOut();
  }

  /// Re-authenticates (Firebase requires a recent sign-in), removes personal
  /// data from Firestore, then deletes the Auth user.
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (isPasswordUser) {
      final credential = EmailAuthProvider.credential(email: user.email ?? '', password: password ?? '');
      await user.reauthenticateWithCredential(credential);
    } else if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
    } else {
      await user.reauthenticateWithProvider(GoogleAuthProvider());
    }
    await _push.unregister(user.uid);
    await _users.deleteAllData(user.uid);
    await user.delete();
  }
}
