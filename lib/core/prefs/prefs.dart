import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers.dart';

/// Injected in main() so reads are synchronous. Holds only language and theme.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

const supportedLanguageCodes = ['ar', 'fr', 'en'];

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final code = ref.watch(sharedPrefsProvider).getString('locale');
    return (code != null && supportedLanguageCodes.contains(code)) ? Locale(code) : null;
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref.read(sharedPrefsProvider).setString('locale', locale.languageCode);
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      try {
        await ref.read(userRepositoryProvider).updateLocale(uid, locale.languageCode);
      } catch (_) {
        // The language also lives on the device; the profile copy is best effort.
      }
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.watch(sharedPrefsProvider).getString('theme');
    return ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPrefsProvider).setString('theme', mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
