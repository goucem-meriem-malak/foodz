import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'fade_slide_in.dart';
import 'language_menu.dart';

/// Shared frame for sign in, sign up, reset password and profile completion.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showLanguage = true,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showLanguage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final items = <Widget>[
      Center(
        child: Image.asset('assets/brand/logo.png', width: 80, height: 80, filterQuality: FilterQuality.medium),
      ),
      const SizedBox(height: Space.s24),
      Text(title, style: text.headlineMedium, textAlign: TextAlign.center),
      const SizedBox(height: Space.s8),
      Text(subtitle, style: text.bodyMedium?.copyWith(color: p.textMuted), textAlign: TextAlign.center),
      const SizedBox(height: Space.s32),
      ...children,
    ];
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.s24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Layout.formWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++) FadeSlideIn(index: i, child: items[i]),
                    ],
                  ),
                ),
              ),
            ),
            if (showLanguage)
              const PositionedDirectional(top: Space.s8, end: Space.s8, child: LanguageMenu()),
          ],
        ),
      ),
    );
  }
}
