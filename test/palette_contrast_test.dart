import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodz/core/theme/tokens.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final entry in {'light': FoodzPalette.light, 'dark': FoodzPalette.dark}.entries) {
    final p = entry.value;
    final pairs = <String, (Color, Color)>{
      'text on bg': (p.text, p.bg),
      'text on surface': (p.text, p.surface),
      'text on tonal': (p.text, p.surfaceTonal),
      'muted on bg': (p.textMuted, p.bg),
      'muted on surface': (p.textMuted, p.surface),
      'muted on tonal': (p.textMuted, p.surfaceTonal),
      'onPrimary on primary': (p.onPrimary, p.primary),
      'onAccent on accent': (p.onAccent, p.accent),
      'primary on bg': (p.primary, p.bg),
      'primary on surface': (p.primary, p.surface),
      'success on surface': (p.success, p.surface),
      'warning on surface': (p.warning, p.surface),
      'error on surface': (p.error, p.surface),
      'onError on error': (p.onError, p.error),
    };
    for (final pair in pairs.entries) {
      test('${entry.key}: ${pair.key} meets WCAG AA (4.5:1)', () {
        expect(_ratio(pair.value.$1, pair.value.$2), greaterThanOrEqualTo(4.5));
      });
    }
  }
}
