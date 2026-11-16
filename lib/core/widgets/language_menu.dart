import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../prefs/prefs.dart';

const languageNames = {'ar': 'العربية', 'fr': 'Français', 'en': 'English'};

/// Compact language switcher for screens that have no settings page yet.
class LanguageMenu extends ConsumerWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      tooltip: context.l10n.language,
      icon: const Icon(Icons.translate_rounded),
      initialValue: current,
      onSelected: (code) => ref.read(localeProvider.notifier).set(Locale(code)),
      itemBuilder: (context) => [
        for (final entry in languageNames.entries)
          PopupMenuItem<String>(value: entry.key, child: Text(entry.value)),
      ],
    );
  }
}
