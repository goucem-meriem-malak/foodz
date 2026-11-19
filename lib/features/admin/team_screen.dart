import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_list.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/app_user.dart';
import '../../data/models/user_role.dart';
import '../../data/providers.dart';

/// Staff and customers. The owner promotes registered users to admin, chef or
/// delivery. Admins and the owner can block or unblock customers.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  String _query = '';

  Future<void> _run(Future<void> Function() action) async {
    final l = context.l10n;
    try {
      await action();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final team = ref.watch(teamProvider);
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isOwner = ref.watch(currentRoleProvider) == UserRole.owner;
    final repo = ref.read(teamRepositoryProvider);

    return PageList(
      title: l.navTeam,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: l.searchPeople,
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: p.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.lg)),
          ),
        ),
        if (isOwner) ...[
          const SizedBox(height: Space.s8),
          Text(l.teamHelp, style: text.bodySmall?.copyWith(color: p.textMuted)),
        ],
        const SizedBox(height: Space.s16),
        team.when(
          loading: () => const ListSkeleton(),
          error: (_, __) => StateView(
            icon: Icons.lock_outline_rounded,
            isError: true,
            title: l.somethingWrongTitle,
            message: l.errNetwork,
            actionLabel: l.retry,
            onAction: () => ref.invalidate(teamProvider),
          ),
          data: (all) {
            final list = all
                .where((u) =>
                    _query.isEmpty ||
                    u.name.toLowerCase().contains(_query) ||
                    u.email.toLowerCase().contains(_query) ||
                    u.phone.contains(_query))
                .toList();
            if (list.isEmpty) return StateView(icon: Icons.group_outlined, title: l.noPeople);
            return Column(
              children: [
                for (final u in list) ...[
                  _PersonCard(
                    user: u,
                    isSelf: u.uid == myUid,
                    canChangeRole: isOwner && u.uid != myUid && u.role != UserRole.owner,
                    onRole: (r) => _run(() => repo.setRole(u.uid, r)),
                    onBlock: (b) => _run(() => repo.setBlocked(u.uid, b)),
                  ),
                  const SizedBox(height: Space.s8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.user,
    required this.isSelf,
    required this.canChangeRole,
    required this.onRole,
    required this.onBlock,
  });

  final AppUser user;
  final bool isSelf;
  final bool canChangeRole;
  final ValueChanged<UserRole> onRole;
  final ValueChanged<bool> onBlock;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final canBlock = !isSelf && user.role == UserRole.client;
    return AppCard(
      padding: const EdgeInsets.all(Space.s12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: text.titleSmall),
                Text(user.email, style: text.bodySmall?.copyWith(color: p.textMuted), textDirection: TextDirection.ltr),
                Text(user.phone, style: text.bodySmall?.copyWith(color: p.textMuted), textDirection: TextDirection.ltr),
                const SizedBox(height: Space.s4),
                Wrap(
                  spacing: Space.s8,
                  children: [
                    Chip(
                      label: Text(l.role(user.role)),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: p.outline),
                      backgroundColor: p.surfaceTonal,
                    ),
                    if (user.blocked)
                      Chip(
                        label: Text(l.blockedTag),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: p.error.withValues(alpha: 0.12),
                        labelStyle: TextStyle(color: p.error),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canChangeRole)
            PopupMenuButton<UserRole>(
              tooltip: l.changeRole,
              icon: const Icon(Icons.manage_accounts_rounded),
              onSelected: onRole,
              itemBuilder: (_) => [
                for (final r in [UserRole.client, UserRole.admin, UserRole.chef, UserRole.delivery])
                  CheckedPopupMenuItem(value: r, checked: r == user.role, child: Text(l.role(r))),
              ],
            ),
          if (canBlock)
            IconButton(
              tooltip: user.blocked ? l.unblock : l.block,
              icon: Icon(user.blocked ? Icons.lock_open_rounded : Icons.block_rounded),
              onPressed: () => onBlock(!user.blocked),
            ),
        ],
      ),
    );
  }
}
