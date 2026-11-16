import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum BannerKind { error, success, info }

/// Inline message with a tinted background, for form errors and notices.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.message, this.kind = BannerKind.info, this.action});

  final String message;
  final BannerKind kind;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (Color tone, IconData icon) = switch (kind) {
      BannerKind.error => (p.error, Icons.error_outline_rounded),
      BannerKind.success => (p.success, Icons.check_circle_outline_rounded),
      BannerKind.info => (p.primary, Icons.info_outline_rounded),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.s16),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: tone.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tone, size: 22),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                  if (action != null) ...[const SizedBox(height: Space.s8), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
