import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/legal_version.dart';
import '../../data/models/user_role.dart';
import '../../data/providers.dart';
import '../../features/admin/admin_orders_screen.dart';
import '../../features/admin/dish_editor_screen.dart';
import '../../features/admin/menu_manager_screen.dart';
import '../../features/admin/team_screen.dart';
import '../../features/auth/accept_terms_screen.dart';
import '../../features/auth/blocked_screen.dart';
import '../../features/auth/complete_profile_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/cart/checkout_screen.dart';
import '../../features/delivery/delivery_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/kitchen/kitchen_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/menu/menu_screen.dart';
import '../../features/orders/my_orders_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/owner/restaurant_settings_screen.dart';
import '../../features/owner/stats_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'transitions.dart';

const _authPaths = {'/sign-in', '/sign-up', '/forgot-password'};
const _gatedPaths = {'/complete-profile', '/accept-terms', '/blocked'};

// Screens each kind of person may open. This only decides what is shown: the
// real permissions are enforced by firestore.rules.
const _guestPaths = {'/home', '/orders', '/cart', '/settings'};
const _clientPaths = {'/home', '/orders', '/cart', '/checkout', '/settings'};
const _chefPaths = {'/kitchen', '/settings'};
const _courierPaths = {'/deliveries', '/settings'};
const _adminPaths = {'/admin', '/menu-manager', '/team', '/settings'};
const _ownerPaths = {..._adminPaths, '/restaurant', '/stats'};

String landingFor(UserRole? role) => switch (role) {
      UserRole.chef => '/kitchen',
      UserRole.delivery => '/deliveries',
      UserRole.admin || UserRole.owner => '/admin',
      _ => '/home',
    };

bool _allowed(UserRole role, String path) {
  if (path.startsWith('/order/')) return true;
  return switch (role) {
    UserRole.client => _clientPaths.contains(path),
    UserRole.chef => _chefPaths.contains(path),
    UserRole.delivery => _courierPaths.contains(path),
    UserRole.admin => _adminPaths.contains(path) || path.startsWith('/dish-editor/'),
    UserRole.owner => _ownerPaths.contains(path) || path.startsWith('/dish-editor/'),
  };
}

/// Tells go_router to re-run `redirect` when the session or profile changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(appUserProvider, (_, __) => notifyListeners());
    _ref.listen(signUpInProgressProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.matchedLocation;
    if (path.startsWith('/legal')) return null;

    final auth = _ref.read(authStateProvider);
    if (auth.isLoading) return null;

    final user = auth.valueOrNull;
    if (user == null) {
      // Guests can browse the menu, look at the cart, change settings and read legal texts.
      if (_authPaths.contains(path) || _guestPaths.contains(path)) return null;
      return path == '/checkout' ? '/sign-in' : '/home';
    }

    if (_ref.read(signUpInProgressProvider)) return null;
    final profile = _ref.read(appUserProvider);
    if (profile.isLoading || profile.hasError) return null;

    final me = profile.valueOrNull;
    if (me == null) return path == '/complete-profile' ? null : '/complete-profile';
    if (me.blocked) return path == '/blocked' ? null : '/blocked';
    if (me.termsVersion != LegalVersions.current) {
      return path == '/accept-terms' ? null : '/accept-terms';
    }
    if (_authPaths.contains(path) || _gatedPaths.contains(path)) return landingFor(me.role);
    if (!_allowed(me.role, path)) return landingFor(me.role);
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  GoRoute tab(String path, Widget screen) =>
      GoRoute(path: path, builder: (context, state) => screen);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: refresh.redirect,
    routes: [
      // Branch order matters: HomeShell maps these indexes to its tabs.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [tab('/home', const MenuScreen())]),
          StatefulShellBranch(routes: [tab('/orders', const MyOrdersScreen())]),
          StatefulShellBranch(routes: [tab('/kitchen', const KitchenScreen())]),
          StatefulShellBranch(routes: [tab('/deliveries', const DeliveryScreen())]),
          StatefulShellBranch(routes: [tab('/admin', const AdminOrdersScreen())]),
          StatefulShellBranch(routes: [tab('/menu-manager', const MenuManagerScreen())]),
          StatefulShellBranch(routes: [tab('/team', const TeamScreen())]),
          StatefulShellBranch(routes: [tab('/restaurant', const RestaurantSettingsScreen())]),
          StatefulShellBranch(routes: [tab('/settings', const SettingsScreen())]),
        ],
      ),
      GoRoute(
        path: '/cart',
        pageBuilder: (context, state) => fadeSlidePage(state, const CartScreen()),
      ),
      GoRoute(
        path: '/checkout',
        pageBuilder: (context, state) => fadeSlidePage(state, const CheckoutScreen()),
      ),
      GoRoute(
        path: '/order/:id',
        pageBuilder: (context, state) =>
            fadeSlidePage(state, OrderDetailScreen(orderId: state.pathParameters['id'] ?? '')),
      ),
      GoRoute(
        path: '/stats',
        pageBuilder: (context, state) => fadeSlidePage(state, const StatsScreen()),
      ),
      GoRoute(
        path: '/dish-editor/:id',
        pageBuilder: (context, state) =>
            fadeSlidePage(state, DishEditorScreen(dishId: state.pathParameters['id'] ?? 'new')),
      ),
      GoRoute(
        path: '/sign-in',
        pageBuilder: (context, state) => fadeSlidePage(state, const SignInScreen()),
      ),
      GoRoute(
        path: '/sign-up',
        pageBuilder: (context, state) => fadeSlidePage(state, const SignUpScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => fadeSlidePage(state, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/complete-profile',
        pageBuilder: (context, state) => fadeSlidePage(state, const CompleteProfileScreen()),
      ),
      GoRoute(
        path: '/accept-terms',
        pageBuilder: (context, state) => fadeSlidePage(state, const AcceptTermsScreen()),
      ),
      GoRoute(
        path: '/blocked',
        pageBuilder: (context, state) => fadeSlidePage(state, const BlockedScreen()),
      ),
      GoRoute(
        path: '/legal/:doc',
        pageBuilder: (context, state) =>
            fadeSlidePage(state, LegalScreen(doc: state.pathParameters['doc'] ?? 'terms')),
      ),
    ],
  );
});
