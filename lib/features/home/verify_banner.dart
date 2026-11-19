import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/providers.dart';

/// Asks the user to confirm their email. Staff roles only work after that.
class VerifyBanner extends ConsumerStatefulWidget {
  const VerifyBanner({super.key});

  @override
  ConsumerState<VerifyBanner> createState() => _VerifyBannerState();
}

class _VerifyBannerState extends ConsumerState<VerifyBanner> {
  bool _busy = false;
  String? _note;

  Future<void> _resend() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).resendVerification();
      if (mounted) setState(() => _note = l.emailSent);
    } catch (_) {
      if (mounted) setState(() => _note = l.errGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final ok = await ref.read(authRepositoryProvider).refreshVerification();
      ref.read(authRefreshProvider.notifier).state++;
      if (mounted && !ok) setState(() => _note = l.stillUnverified);
    } catch (_) {
      if (mounted) setState(() => _note = l.errGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return StatusBanner(
      message: _note ?? l.verifyEmailBody,
      action: Wrap(
        spacing: Space.s8,
        children: [
          AppButton(label: l.resendEmail, kind: AppButtonKind.secondary, expand: false, onPressed: _busy ? null : _resend),
          AppButton(label: l.verifiedCheck, kind: AppButtonKind.text, expand: false, onPressed: _busy ? null : _check),
        ],
      ),
    );
  }
}
