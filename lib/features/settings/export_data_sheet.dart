import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../data/models/app_user.dart';

/// Shows everything stored about the user as JSON, which they can copy.
Future<void> showExportDataSheet(BuildContext context, AppUser me) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final l = context.l10n;
      final json = const JsonEncoder.withIndent('  ').convert(me.toExport());
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.s24, Space.s8, Space.s24, Space.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.exportData, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.s8),
            Text(l.exportDataBody, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: Space.s16),
            Container(
              padding: const EdgeInsets.all(Space.s16),
              decoration: BoxDecoration(
                color: context.palette.surfaceTonal,
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              child: SelectableText(
                json,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: Space.s16),
            AppButton(
              label: l.copy,
              icon: Icons.copy_rounded,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: json));
                messenger.showSnackBar(SnackBar(content: Text(l.copied)));
              },
            ),
          ],
        ),
      );
    },
  );
}
