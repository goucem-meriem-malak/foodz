import 'package:flutter/widgets.dart';

import '../../data/models/user_role.dart';
import '../../l10n/gen/app_localizations.dart';

export '../../l10n/gen/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension RoleLabel on AppLocalizations {
  String role(UserRole r) => switch (r) {
        UserRole.client => roleClient,
        UserRole.admin => roleAdmin,
        UserRole.owner => roleOwner,
        UserRole.chef => roleChef,
        UserRole.delivery => roleDelivery,
      };
}

/// Maps a Firebase Auth error code to a friendly message.
/// Returns null when the user simply closed the sign-in window.
String? authErrorMessage(AppLocalizations l, String code) => switch (code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-email' =>
        l.errInvalidCredentials,
      'email-already-in-use' => l.errEmailInUse,
      'weak-password' => l.errWeakPassword,
      'too-many-requests' => l.errTooManyRequests,
      'network-request-failed' => l.errNetwork,
      'user-disabled' => l.errUserDisabled,
      'requires-recent-login' => l.errRecentLogin,
      'popup-closed-by-user' ||
      'cancelled-popup-request' ||
      'canceled' ||
      'web-context-canceled' ||
      'user-cancelled' =>
        null,
      _ => l.errGeneric,
    };
