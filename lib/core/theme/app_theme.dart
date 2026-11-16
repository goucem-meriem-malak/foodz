import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// One theme file. No colours, radii or spacings are hardcoded in widgets.
abstract final class AppTheme {
  static ThemeData light({required bool arabic}) =>
      _build(FoodzPalette.light, Brightness.light, arabic);

  static ThemeData dark({required bool arabic}) =>
      _build(FoodzPalette.dark, Brightness.dark, arabic);

  /// Tabular figures for prices, counters and timers.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static ThemeData _build(FoodzPalette p, Brightness brightness, bool arabic) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.accent,
      onSecondary: p.onAccent,
      error: p.error,
      onError: p.onError,
      surface: p.surface,
      onSurface: p.text,
      surfaceContainerHighest: p.surfaceTonal,
      outline: p.textMuted,
      outlineVariant: p.outline,
    );
    final base = ThemeData(brightness: brightness, useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      textTheme: _textTheme(base.textTheme, p, arabic),
      extensions: <ThemeExtension<dynamic>>[p],
      dividerColor: p.outline,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.surfaceTonal,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.text : p.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? p.primary : p.textMuted, size: 24);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
    );
  }

  // Arabic letters must stay connected: no negative letter-spacing, taller lines.
  static TextTheme _textTheme(TextTheme base, FoodzPalette p, bool arabic) {
    final t = GoogleFonts.cairoTextTheme(base).apply(bodyColor: p.text, displayColor: p.text);

    TextStyle? heading(TextStyle? s, FontWeight weight) {
      if (s == null) return null;
      return s.copyWith(
        fontWeight: weight,
        height: arabic ? 1.4 : 1.15,
        letterSpacing: arabic ? 0 : (s.fontSize ?? 16) * -0.025,
      );
    }

    TextStyle? body(TextStyle? s, [FontWeight? weight]) {
      if (s == null) return null;
      return s.copyWith(fontWeight: weight, height: arabic ? 1.6 : 1.5, letterSpacing: 0);
    }

    return t.copyWith(
      displayLarge: heading(t.displayLarge, FontWeight.w700),
      displayMedium: heading(t.displayMedium, FontWeight.w700),
      displaySmall: heading(t.displaySmall, FontWeight.w700),
      headlineLarge: heading(t.headlineLarge, FontWeight.w700),
      headlineMedium: heading(t.headlineMedium, FontWeight.w700),
      headlineSmall: heading(t.headlineSmall, FontWeight.w700),
      titleLarge: heading(t.titleLarge, FontWeight.w700),
      titleMedium: heading(t.titleMedium, FontWeight.w600),
      titleSmall: heading(t.titleSmall, FontWeight.w600),
      bodyLarge: body(t.bodyLarge),
      bodyMedium: body(t.bodyMedium),
      bodySmall: body(t.bodySmall)?.copyWith(color: p.textMuted),
      labelLarge: body(t.labelLarge, FontWeight.w600),
      labelMedium: body(t.labelMedium, FontWeight.w600),
      labelSmall: body(t.labelSmall, FontWeight.w600),
    );
  }
}
