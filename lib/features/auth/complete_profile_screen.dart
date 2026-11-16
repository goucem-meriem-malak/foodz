import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/security/validators.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/auth_scaffold.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/providers.dart';
import 'legal_checkbox.dart';

/// Shown after Google sign-in (or an interrupted sign-up): the account exists
/// but has no profile yet. Collects the name and phone, and the legal consent.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: ref.read(firebaseAuthProvider).currentUser?.displayName ?? '');
  final _phone = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || !_agreed) return;
    final l = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(userRepositoryProvider).createProfile(
            uid: user.uid,
            name: _name.text,
            phone: Validators.normalizePhone(_phone.text),
            email: user.email ?? '',
            locale: locale,
          );
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
      title: l.completeProfileTitle,
      subtitle: l.completeProfileSubtitle,
      children: [
        Form(
          key: _form,
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
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.phone(v)?.text(l),
                enabled: !_busy,
              ),
              const SizedBox(height: Space.s16),
              LegalCheckbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v)),
              const SizedBox(height: Space.s8),
              AppButton(label: l.continueLabel, onPressed: _agreed ? _submit : null, loading: _busy),
            ],
          ),
        ),
        const SizedBox(height: Space.s16),
        TextButton(
          onPressed: _busy ? null : () => ref.read(authRepositoryProvider).signOut(),
          child: Text(l.signOut),
        ),
      ],
    );
  }
}
