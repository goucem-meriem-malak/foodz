import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/services/push_bootstrap.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/user_role.dart';
import '../../data/providers.dart';
import 'verify_banner.dart';

class _Dest {
  const _Dest(this.branch, this.icon, this.selectedIcon, this.label);
  final int branch; // index of the branch in app_router.dart
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l) label;
}

final _dests = <int, _Dest>{
  0: _Dest(0, Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded, (l) => l.navHome),
  1: _Dest(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, (l) => l.ordersTitle),
  2: _Dest(2, Icons.soup_kitchen_outlined, Icons.soup_kitchen_rounded, (l) => l.navKitchen),
  3: _Dest(3, Icons.delivery_dining_outlined, Icons.delivery_dining_rounded, (l) => l.navDeliveries),
  4: _Dest(4, Icons.notifications_active_outlined, Icons.notifications_active_rounded, (l) => l.navOrders),
  5: _Dest(5, Icons.menu_book_outlined, Icons.menu_book_rounded, (l) => l.navMenu),
  6: _Dest(6, Icons.group_outlined, Icons.group_rounded, (l) => l.navTeam),
  7: _Dest(7, Icons.storefront_outlined, Icons.storefront_rounded, (l) => l.navRestaurant),
  8: _Dest(8, Icons.settings_outlined, Icons.settings_rounded, (l) => l.navSettings),
};

/// Tabs each role sees (branch indexes).
List<_Dest> _destsFor(UserRole? role) {
  final ids = switch (role) {
    UserRole.chef => [2, 8],
    UserRole.delivery => [3, 8],
    UserRole.admin => [4, 5, 6, 8],
    UserRole.owner => [4, 5, 6, 7, 8],
    _ => [0, 1, 8],
  };
  return [for (final i in ids) _dests[i]!];
}

/// Bottom navigation on phones, a side rail on wide screens (web, desktop).
/// The tabs depend on the role: customers get the menu and their orders, the
/// chef the kitchen, delivery people their deliveries, admins and the owner the
/// order board, menu, people and (owner) restaurant settings.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(pushBootstrapProvider);
    final role = ref.watch(currentRoleProvider);
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;
    final verified = ref.watch(emailVerifiedProvider);
    final dests = _destsFor(role);
    final found = dests.indexWhere((d) => d.branch == shell.currentIndex);
    final selected = found < 0 ? 0 : found;
    void go(int i) => shell.goBranch(dests[i].branch, initialLocation: dests[i].branch == shell.currentIndex);

    // Staff need a verified email for the security rules to let them in.
    final needsVerify = signedIn && (role?.isStaff ?? false) && !verified;
    final body = Column(
      children: [
        if (needsVerify)
          SafeArea(
            bottom: false,
            child: Padding(padding: const EdgeInsets.all(Space.s16), child: const VerifyBanner()),
          ),
        Expanded(child: shell),
      ],
    );

    if (MediaQuery.sizeOf(context).width >= Layout.railBreakpoint) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s16),
                child: Image.asset('assets/brand/logo.png', width: 44, height: 44),
              ),
              destinations: [
                for (final d in dests)
                  NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label(l))),
              ],
            ),
            VerticalDivider(width: 1, color: context.palette.outline),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: go,
        destinations: [
          for (final d in dests)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label(l)),
        ],
      ),
    );
  }
}
