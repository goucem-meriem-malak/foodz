import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodz/core/config/legal_version.dart';

void main() {
  test('all three languages define exactly the same texts', () {
    Set<String> keys(String lang) =>
        (jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>)
            .keys
            .where((k) => !k.startsWith('@'))
            .toSet();
    expect(keys('fr'), keys('en'));
    expect(keys('ar'), keys('en'));
  });

  test('every legal text exists in every language and carries the current version', () {
    for (final doc in ['terms', 'privacy']) {
      for (final lang in ['ar', 'fr', 'en']) {
        final file = File('assets/legal/${doc}_$lang.md');
        expect(file.existsSync(), isTrue, reason: file.path);
        expect(file.readAsStringSync(), contains(LegalVersions.current), reason: file.path);
      }
    }
  });
}
