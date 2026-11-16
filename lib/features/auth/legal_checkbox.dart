import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';

/// Unchecked by default. The submit button stays disabled until it is checked.
/// Both documents open inside the app as readable screens.
class LegalCheckbox extends StatelessWidget {
  const LegalCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Layout.minTouch),
            child: Row(
              children: [
                Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
                Expanded(child: Text(l.agreeToLegal, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: Space.s8,
          children: [
            TextButton(onPressed: () => context.push('/legal/terms'), child: Text(l.termsOfUse)),
            TextButton(onPressed: () => context.push('/legal/privacy'), child: Text(l.privacyPolicy)),
          ],
        ),
      ],
    );
  }
}
