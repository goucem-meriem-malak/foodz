import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.obscure = false,
    this.ltr = false,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.enabled = true,
    this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final bool obscure;

  /// Emails, phone numbers and passwords are typed left-to-right even in Arabic.
  final bool ltr;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final IconData? icon;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final edge = p.textMuted.withValues(alpha: 0.4);
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      autofillHints: widget.autofillHints,
      textCapitalization: widget.textCapitalization,
      onFieldSubmitted: widget.onSubmitted,
      textDirection: widget.ltr ? TextDirection.ltr : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        helperMaxLines: 2,
        filled: true,
        fillColor: p.surface,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, color: p.textMuted),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? context.l10n.showPassword : context.l10n.hidePassword,
                icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                color: p.textMuted,
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: Space.s16),
        border: _border(edge),
        enabledBorder: _border(edge),
        disabledBorder: _border(p.outline),
        focusedBorder: _border(p.primary, 2),
        errorBorder: _border(p.error),
        focusedErrorBorder: _border(p.error, 2),
      ),
    );
  }
}
