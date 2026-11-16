import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/security/validators.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/auth_scaffold.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      // Same message whether or not the account exists, to avoid leaking who has one.
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        if (mounted) setState(() => _sent = true);
      } else if (mounted) {
        setState(() => _error = authErrorMessage(l, e.code));
      }
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
      title: l.forgotTitle,
      subtitle: l.forgotSubtitle,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_sent) ...[
                StatusBanner(message: l.resetLinkSent, kind: BannerKind.success),
                const SizedBox(height: Space.s16),
              ],
              if (_error != null) ...[
                StatusBanner(message: _error!, kind: BannerKind.error),
                const SizedBox(height: Space.s16),
              ],
              AppTextField(
                controller: _email,
                label: l.email,
                icon: Icons.mail_outline_rounded,
                ltr: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                validator: (v) => Validators.email(v)?.text(l),
                onSubmitted: (_) => _submit(),
                enabled: !_busy,
              ),
              const SizedBox(height: Space.s16),
              AppButton(label: l.sendResetLink, onPressed: _submit, loading: _busy),
            ],
          ),
        ),
        const SizedBox(height: Space.s16),
        TextButton(onPressed: () => context.go('/sign-in'), child: Text(l.signIn)),
      ],
    );
  }
}
