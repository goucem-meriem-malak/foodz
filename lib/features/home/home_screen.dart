import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/services/push_bootstrap.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/providers.dart';

/// Round 1 home: greeting, verification notice and the "menu is coming" state.
/// The menu, cart and orders replace the placeholder in the next build.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(pushBootstrapProvider);
    final auth = ref.watch(authStateProvider);
    final profile = ref.watch(appUserProvider);
    final verified = ref.watch(emailVerifiedProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final signedIn = auth.valueOrNull != null;

    Widget body;
    if (auth.isLoading || (signedIn && profile.isLoading)) {
      body = const HomeSkeleton();
    } else if (profile.hasError) {
      body = StateView(
        icon: Icons.cloud_off_rounded,
        isError: true,
        title: l.somethingWrongTitle,
        message: l.errNetwork,
        actionLabel: l.retry,
        onAction: () => ref.invalidate(appUserProvider),
      );
    } else {
      final me = profile.valueOrNull;
      final text = Theme.of(context).textTheme;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: Text(
              me == null ? l.homeGreetingGuest : l.homeGreeting(me.name.split(' ').first),
              style: text.headlineMedium,
            ),
          ),
          if (me != null) ...[
            const SizedBox(height: Space.s8),
            FadeSlideIn(
              index: 1,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Chip(
                  label: Text(l.role(me.role)),
                  side: BorderSide(color: context.palette.outline),
                  backgroundColor: context.palette.surfaceTonal,
                ),
              ),
            ),
          ],
          if (signedIn && !verified) ...[
            const SizedBox(height: Space.s16),
            FadeSlideIn(index: 2, child: const _VerifyBanner()),
          ],
          const SizedBox(height: Space.s24),
          FadeSlideIn(
            index: 3,
            child: Container(
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: context.palette.outline),
              ),
              child: StateView(
                icon: Icons.restaurant_menu_rounded,
                title: l.homeMenuSoonTitle,
                message: l.homeMenuSoonBody,
                actionLabel: signedIn ? null : l.signInToOrder,
                onAction: signedIn ? null : () => context.go('/sign-in'),
              ),
            ),
          ),
          if (settings != null && settings.hasContact) ...[
            const SizedBox(height: Space.s16),
            Text(l.contactTitle, style: text.titleSmall),
            const SizedBox(height: Space.s4),
            Text(
              [settings.contactPhone, settings.contactEmail].where((s) => s.isNotEmpty).join('  ·  '),
              style: text.bodyMedium?.copyWith(color: context.palette.textMuted),
              textDirection: TextDirection.ltr,
            ),
          ],
        ],
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(appUserProvider);
          ref.invalidate(settingsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(Space.s24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Layout.maxContent),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyBanner extends ConsumerStatefulWidget {
  const _VerifyBanner();

  @override
  ConsumerState<_VerifyBanner> createState() => _VerifyBannerState();
}

class _VerifyBannerState extends ConsumerState<_VerifyBanner> {
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
