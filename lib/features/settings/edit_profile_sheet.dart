import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/security/validators.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/models/app_user.dart';
import '../../data/providers.dart';

Future<void> showEditProfileSheet(BuildContext context, AppUser me) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _EditProfileSheet(me: me),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.me});
  final AppUser me;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.me.name);
  late final _phone = TextEditingController(text: widget.me.phone);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(userRepositoryProvider)
          .updateProfile(widget.me.uid, name: _name.text, phone: Validators.normalizePhone(_phone.text));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l.profileSaved)));
    } catch (_) {
      if (mounted) setState(() => _error = l.errGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.s24,
        Space.s8,
        Space.s24,
        Space.s24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.editProfile, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Space.s16),
              if (_error != null) ...[
                StatusBanner(message: _error!, kind: BannerKind.error),
                const SizedBox(height: Space.s16),
              ],
              AppTextField(
                controller: _name,
                label: l.fullName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.name(v)?.text(l),
                enabled: !_busy,
              ),
              const SizedBox(height: Space.s16),
              AppTextField(
                controller: _phone,
                label: l.phone,
                helper: l.phoneHelper,
                ltr: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.phone(v)?.text(l),
                enabled: !_busy,
              ),
              const SizedBox(height: Space.s24),
              AppButton(label: l.save, onPressed: _save, loading: _busy),
            ],
          ),
        ),
      ),
    );
  }
}
