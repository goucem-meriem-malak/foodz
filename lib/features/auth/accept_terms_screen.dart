import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/auth_scaffold.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/providers.dart';
import 'legal_checkbox.dart';

/// Shown when the legal texts changed since the user last accepted them.
class AcceptTermsScreen extends ConsumerStatefulWidget {
  const AcceptTermsScreen({super.key});

  @override
  ConsumerState<AcceptTermsScreen> createState() => _AcceptTermsScreenState();
}

class _AcceptTermsScreenState extends ConsumerState<AcceptTermsScreen> {
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(userRepositoryProvider).acceptCurrentTerms(uid);
    } catch (_) {
      if (mounted) setState(() => _error = l.errGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
      title: l.termsUpdatedTitle,
      subtitle: l.termsUpdatedBody,
      children: [
        if (_error != null) ...[
          StatusBanner(message: _error!, kind: BannerKind.error),
          const SizedBox(height: Space.s16),
        ],
        LegalCheckbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v)),
        const SizedBox(height: Space.s8),
        AppButton(label: l.accept, onPressed: _agreed ? _accept : null, loading: _busy),
        const SizedBox(height: Space.s16),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/home');
                },
          child: Text(l.signOut),
        ),
      ],
    );
  }
}
