import 'package:flutter/material.dart';

/// Spacing scale. Multiples of 4, used on every screen.
abstract final class Space {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
  static const double s64 = 64;
}

/// Corner radii. Soft and friendly. Nested radius = outer radius minus padding.
abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;
}

/// Motion. Everything decelerates, nothing is linear.
abstract final class Motion {
  static const Curve decelerate = Cubic(0.16, 1, 0.3, 1);
  static const Duration tap = Duration(milliseconds: 150);
  static const Duration screen = Duration(milliseconds: 320);
  static const Duration sheet = Duration(milliseconds: 360);
  static const Duration stagger = Duration(milliseconds: 40);
  static const double enterOffset = 8;

  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);
}

abstract final class Layout {
  static const double maxContent = 1100;
  static const double formWidth = 440;
  static const double railBreakpoint = 840;
  static const double minTouch = 48;
}

/// Colours derived from the logo: signal red (primary) and flame orange (accent) on near-black.
/// Contrast checked against WCAG AA (see docs/DOCUMENTATION.md).
@immutable
class FoodzPalette extends ThemeExtension<FoodzPalette> {
  const FoodzPalette({
    required this.bg,
    required this.surface,
    required this.surfaceTonal,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.text,
    required this.textMuted,
    required this.outline,
    required this.success,
    required this.warning,
    required this.error,
    required this.onError,
  });

  final Color bg;
  final Color surface;
  final Color surfaceTonal;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;
  final Color text;
  final Color textMuted;
  final Color outline;
  final Color success;
  final Color warning;
  final Color error;
  final Color onError;

  static const FoodzPalette light = FoodzPalette(
    bg: Color(0xFFFFF7F5),
    surface: Color(0xFFFFFFFF),
    surfaceTonal: Color(0xFFFFE9E4),
    primary: Color(0xFFDC0A22),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFFD610E),
    onAccent: Color(0xFF2B0E00),
    text: Color(0xFF2B1716),
    textMuted: Color(0xFF6B5755),
    outline: Color(0x14000000),
    success: Color(0xFF1B7F37),
    warning: Color(0xFFB45309),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
  );

  static const FoodzPalette dark = FoodzPalette(
    bg: Color(0xFF0E0A0A),
    surface: Color(0xFF1A1212),
    surfaceTonal: Color(0xFF251A1A),
    primary: Color(0xFFFF5A66),
    onPrimary: Color(0xFF2B0006),
    accent: Color(0xFFFD610E),
    onAccent: Color(0xFF2B0E00),
    text: Color(0xFFF8EEEC),
    textMuted: Color(0xFFBCA7A5),
    outline: Color(0x14FFFFFF),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF410002),
  );

  @override
  FoodzPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceTonal,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? onAccent,
    Color? text,
    Color? textMuted,
    Color? outline,
    Color? success,
    Color? warning,
    Color? error,
    Color? onError,
  }) {
    return FoodzPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceTonal: surfaceTonal ?? this.surfaceTonal,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      outline: outline ?? this.outline,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      onError: onError ?? this.onError,
    );
  }

  @override
  FoodzPalette lerp(ThemeExtension<FoodzPalette>? other, double t) {
    if (other is! FoodzPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return FoodzPalette(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surfaceTonal: mix(surfaceTonal, other.surfaceTonal),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      outline: mix(outline, other.outline),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
    );
  }
}

extension PaletteContext on BuildContext {
  FoodzPalette get palette => Theme.of(this).extension<FoodzPalette>()!;
}
