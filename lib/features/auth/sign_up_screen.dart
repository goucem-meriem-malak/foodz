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
import 'legal_checkbox.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || !_agreed) return;
    final l = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    setState(() {
      _busy = true;
      _error = null;
    });
    ref.read(signUpInProgressProvider.notifier).state = true;
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
            name: _name.text,
            phone: Validators.normalizePhone(_phone.text),
            locale: locale,
          );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(l, e.code));
    } catch (_) {
      if (mounted) setState(() => _error = l.errGeneric);
    } finally {
      ref.read(signUpInProgressProvider.notifier).state = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
      title: l.signUpTitle,
      subtitle: l.signUpSubtitle,
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
                  controller: _name,
                  label: l.fullName,
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => Validators.name(v)?.text(l),
                  enabled: !_busy,
                ),
                const SizedBox(height: Space.s16),
                AppTextField(
                  controller: _phone,
                  label: l.phone,
                  hint: l.phoneHint,
                  helper: l.phoneHelper,
                  icon: Icons.phone_outlined,
                  ltr: true,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: (v) => Validators.phone(v)?.text(l),
                  enabled: !_busy,
                ),
                const SizedBox(height: Space.s16),
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
                  helper: l.passwordHelper,
                  icon: Icons.lock_outline_rounded,
                  ltr: true,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => Validators.password(v)?.text(l),
                  enabled: !_busy,
                ),
                const SizedBox(height: Space.s16),
                LegalCheckbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v)),
                const SizedBox(height: Space.s8),
                AppButton(
                  label: l.signUp,
                  onPressed: _agreed ? _submit : null,
                  loading: _busy,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l.haveAccount),
            TextButton(onPressed: () => context.go('/sign-in'), child: Text(l.signIn)),
          ],
        ),
      ],
    );
  }
}
