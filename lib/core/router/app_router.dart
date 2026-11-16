import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/legal_version.dart';
import '../../data/providers.dart';
import '../../features/auth/accept_terms_screen.dart';
import '../../features/auth/blocked_screen.dart';
import '../../features/auth/complete_profile_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'transitions.dart';

const _authPaths = {'/sign-in', '/sign-up', '/forgot-password'};
const _gatedPaths = {'/complete-profile', '/accept-terms', '/blocked'};

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
      // Guests can browse the menu, change settings and read legal texts.
      if (_authPaths.contains(path) || path == '/home' || path == '/settings') return null;
      return '/home';
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
    if (_authPaths.contains(path) || _gatedPaths.contains(path)) return '/home';
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: refresh.redirect,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          ]),
        ],
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
