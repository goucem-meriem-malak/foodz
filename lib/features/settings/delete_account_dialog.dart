import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/providers.dart';

Future<void> showDeleteAccountDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _DeleteAccountDialog());
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final repo = ref.read(authRepositoryProvider);
    if (repo.isPasswordUser && _password.text.isEmpty) {
      setState(() => _error = l.errRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.deleteAccount(password: _password.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeleted)));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(l, e.code));
    } catch (_) {
      if (mounted) setState(() => _error = l.errGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final needsPassword = ref.watch(authRepositoryProvider).isPasswordUser;
    return AlertDialog(
      title: Text(l.deleteAccount),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.deleteAccountBody),
            if (needsPassword) ...[
              const SizedBox(height: Space.s16),
              AppTextField(
                controller: _password,
                label: l.deleteAccountPassword,
                obscure: true,
                ltr: true,
                enabled: !_busy,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: Space.s16),
              StatusBanner(message: _error!, kind: BannerKind.error),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l.cancel)),
        TextButton(
          onPressed: _busy ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: context.palette.error),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.delete),
        ),
      ],
    );
  }
}
