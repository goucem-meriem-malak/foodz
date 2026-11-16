import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/push_service.dart';
import 'models/app_settings.dart';
import 'models/app_user.dart';
import 'models/user_role.dart';
import 'repositories/auth_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/user_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref.watch(firestoreProvider)));

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository(ref.watch(firestoreProvider)));

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository(ref.watch(firestoreProvider)));

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      ref.watch(firebaseAuthProvider),
      ref.watch(userRepositoryProvider),
      ref.watch(pushServiceProvider),
    ));

/// Signed-in Firebase user (null for guests).
final authStateProvider =
    StreamProvider<User?>((ref) => ref.watch(firebaseAuthProvider).userChanges());

/// Bumped after the user reloads their profile (for example after verifying email).
final authRefreshProvider = StateProvider<int>((ref) => 0);

/// True while the sign-up form is creating the account and profile, so the
/// router does not flash the "complete profile" page in between.
final signUpInProgressProvider = StateProvider<bool>((ref) => false);

/// Profile document of the signed-in user. Re-subscribes only when the uid changes.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authStateProvider.select((v) => v.valueOrNull?.uid));
  if (uid == null) return Stream<AppUser?>.value(null);
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

final settingsProvider =
    StreamProvider<AppSettings>((ref) => ref.watch(settingsRepositoryProvider).watch());

final currentRoleProvider = Provider<UserRole?>((ref) => ref.watch(appUserProvider).valueOrNull?.role);

final emailVerifiedProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  ref.watch(authRefreshProvider);
  return ref.watch(firebaseAuthProvider).currentUser?.emailVerified ?? false;
});
