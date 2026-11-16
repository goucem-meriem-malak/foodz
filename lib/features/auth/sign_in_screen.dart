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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(l, e.code));
    } catch (_) {
      if (mounted) setState(() => _error = l.errGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await _run(() => ref.read(authRepositoryProvider).signIn(_email.text, _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = ref.watch(authRepositoryProvider);
    return AuthScaffold(
      title: l.signInTitle,
      subtitle: l.signInSubtitle,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) => Validators.email(v)?.text(l),
                  enabled: !_busy,
                ),
                const SizedBox(height: Space.s16),
                AppTextField(
                  controller: _password,
                  label: l.password,
                  icon: Icons.lock_outline_rounded,
                  ltr: true,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) => Validators.required(v)?.text(l),
                  onSubmitted: (_) => _submit(),
                  enabled: !_busy,
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: _busy ? null : () => context.push('/forgot-password'),
                    child: Text(l.forgotPassword),
                  ),
                ),
                const SizedBox(height: Space.s8),
                AppButton(label: l.signIn, onPressed: _submit, loading: _busy),
              ],
            ),
          ),
        ),
        if (auth.googleSupported) ...[
          const SizedBox(height: Space.s16),
          AppButton(
            label: l.continueWithGoogle,
            kind: AppButtonKind.secondary,
            icon: Icons.g_mobiledata_rounded,
            onPressed: _busy ? null : () => _run(auth.signInWithGoogle),
          ),
        ],
        const SizedBox(height: Space.s24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l.noAccount),
            TextButton(onPressed: () => context.go('/sign-up'), child: Text(l.signUp)),
          ],
        ),
        TextButton(onPressed: () => context.go('/home'), child: Text(l.browseAsGuest)),
      ],
    );
  }
}
