import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/state_view.dart';
import '../../data/providers.dart';

class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: StateView(
          icon: Icons.block_rounded,
          isError: true,
          title: l.blockedTitle,
          message: l.blockedBody,
          actionLabel: l.signOut,
          onAction: () => ref.read(authRepositoryProvider).signOut(),
        ),
      ),
    );
  }
}
