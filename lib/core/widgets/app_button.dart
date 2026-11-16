import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

enum AppButtonKind { primary, secondary, text }

/// 52px tall (touch target above 48), press scale 0.98, haptic tick.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = widget.onPressed != null && !widget.loading;
    final (Color bg, Color fg, Color border) = switch (widget.kind) {
      AppButtonKind.primary => (p.primary, p.onPrimary, Colors.transparent),
      AppButtonKind.secondary => (p.surfaceTonal, p.text, p.outline),
      AppButtonKind.text => (Colors.transparent, p.primary, Colors.transparent),
    };

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: fg),
            const SizedBox(width: Space.s8),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontSize: 16),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedScale(
        scale: _down && enabled ? 0.98 : 1,
        duration: Motion.reduced(context) ? Duration.zero : Motion.tap,
        curve: Motion.decelerate,
        child: Opacity(
          opacity: (enabled || widget.loading) ? 1 : 0.5,
          child: Material(
            color: bg,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.lg),
              side: BorderSide(color: border),
            ),
            child: InkWell(
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      widget.onPressed!();
                    }
                  : null,
              onHighlightChanged: (v) => setState(() => _down = v),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s24, vertical: Space.s12),
                  child: Center(widthFactor: widget.expand ? null : 1, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
