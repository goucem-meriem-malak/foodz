import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/env.dart';
import 'core/l10n/l10n.dart';
import 'core/prefs/prefs.dart';
import 'core/router/app_router.dart';
import 'core/services/background_push.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/state_view.dart';
import 'features/splash/splash_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    runApp(const _SetupIncompleteApp());
    return;
  }

  await Firebase.initializeApp(options: Env.firebaseOptions);
  registerBackgroundPush();
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const FoodzApp(),
  ));
}

class FoodzApp extends ConsumerWidget {
  const FoodzApp({super.key});

  static const _locales = [Locale('ar'), Locale('fr'), Locale('en')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final mode = ref.watch(themeModeProvider);
    final arabic = (locale?.languageCode ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode) == 'ar';

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: locale,
      supportedLocales: _locales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Unsupported device languages fall back to French, the most common
      // written language of Algerian businesses after Arabic.
      localeResolutionCallback: (device, supported) {
        for (final s in supported) {
          if (s.languageCode == device?.languageCode) return s;
        }
        return const Locale('fr');
      },
      themeMode: mode,
      theme: AppTheme.light(arabic: arabic),
      darkTheme: AppTheme.dark(arabic: arabic),
      builder: (context, child) => SplashGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Shown instead of crashing when Firebase keys were not supplied.
class _SetupIncompleteApp extends StatelessWidget {
  const _SetupIncompleteApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(arabic: false),
      darkTheme: AppTheme.dark(arabic: false),
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: StateView(
              icon: Icons.settings_suggest_rounded,
              title: context.l10n.setupIncompleteTitle,
              message: context.l10n.setupIncompleteBody,
            ),
          ),
        ),
      ),
    );
  }
}
