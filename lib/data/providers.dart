import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/image_upload_service.dart';
import '../core/services/notify_service.dart';
import '../core/services/push_service.dart';
import 'models/app_settings.dart';
import 'models/app_user.dart';
import 'models/menu.dart';
import 'models/order.dart';
import 'models/user_role.dart';
import 'repositories/auth_repository.dart';
import 'repositories/menu_repository.dart';
import 'repositories/orders_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/team_repository.dart';
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

// ---------- menu ----------
final menuRepositoryProvider =
    Provider<MenuRepository>((ref) => MenuRepository(ref.watch(firestoreProvider)));

final categoriesProvider =
    StreamProvider<List<MenuCategory>>((ref) => ref.watch(menuRepositoryProvider).watchCategories());

final dishesProvider = StreamProvider<List<Dish>>((ref) => ref.watch(menuRepositoryProvider).watchDishes());

// ---------- orders ----------
final notifyServiceProvider =
    Provider<NotifyService>((ref) => NotifyService(ref.watch(firebaseAuthProvider)));

final imageUploadServiceProvider =
    Provider<ImageUploadService>((ref) => ImageUploadService(ref.watch(firebaseAuthProvider)));

final ordersRepositoryProvider = Provider<OrdersRepository>(
    (ref) => OrdersRepository(ref.watch(firestoreProvider), ref.watch(notifyServiceProvider)));

final _uidProvider = Provider<String?>((ref) => ref.watch(authStateProvider.select((v) => v.valueOrNull?.uid)));

/// The signed-in customer's own orders, newest first.
final myOrdersProvider = StreamProvider<List<Order>>((ref) {
  final uid = ref.watch(_uidProvider);
  if (uid == null) return Stream.value(const <Order>[]);
  return ref.watch(ordersRepositoryProvider).watchMine(uid);
});

final orderProvider = StreamProvider.family<Order?, String>(
    (ref, id) => ref.watch(ordersRepositoryProvider).watchOrder(id));

/// Contact details of one order. Null when the caller may not see them.
final contactProvider = FutureProvider.autoDispose.family<OrderContact?, String>(
    (ref, id) => ref.watch(ordersRepositoryProvider).contactOf(id));

bool _hasRole(Ref ref, Set<UserRole> roles) {
  final role = ref.watch(currentRoleProvider);
  return role != null && roles.contains(role);
}

/// Admin and owner: orders that are still open.
final openOrdersProvider = StreamProvider<List<Order>>((ref) {
  if (!_hasRole(ref, {UserRole.admin, UserRole.owner})) return Stream.value(const <Order>[]);
  return ref.watch(ordersRepositoryProvider).watchStatuses([
    OrderStatus.placed,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.outForDelivery,
  ]);
});

final historyOrdersProvider = StreamProvider<List<Order>>((ref) {
  if (!_hasRole(ref, {UserRole.admin, UserRole.owner})) return Stream.value(const <Order>[]);
  return ref.watch(ordersRepositoryProvider).watchHistory();
});

/// Chef: confirmed orders to cook, orders being cooked, and finished ones waiting for pickup.
final kitchenOrdersProvider = StreamProvider<List<Order>>((ref) {
  if (!_hasRole(ref, {UserRole.chef})) return Stream.value(const <Order>[]);
  return ref
      .watch(ordersRepositoryProvider)
      .watchStatuses([OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.ready]);
});

/// Delivery: orders that are coming up (not taken yet).
final courierBoardProvider = StreamProvider<List<Order>>((ref) {
  if (!_hasRole(ref, {UserRole.delivery})) return Stream.value(const <Order>[]);
  return ref
      .watch(ordersRepositoryProvider)
      .watchStatuses([OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.ready]);
});

/// Delivery: orders this person took.
final courierMineProvider = StreamProvider<List<Order>>((ref) {
  final uid = ref.watch(_uidProvider);
  if (uid == null || !_hasRole(ref, {UserRole.delivery})) return Stream.value(const <Order>[]);
  return ref.watch(ordersRepositoryProvider).watchCourierOrders(uid);
});

// ---------- team ----------
final teamRepositoryProvider =
    Provider<TeamRepository>((ref) => TeamRepository(ref.watch(firestoreProvider)));

final teamProvider = StreamProvider<List<AppUser>>((ref) {
  if (!_hasRole(ref, {UserRole.admin, UserRole.owner})) return Stream.value(const <AppUser>[]);
  return ref.watch(teamRepositoryProvider).watchUsers();
});
