import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/prefs.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/language_menu.dart';
import '../../data/providers.dart';
import 'delete_account_dialog.dart';
import 'edit_profile_sheet.dart';
import 'export_data_sheet.dart';

const appVersion = '1.0.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final me = ref.watch(appUserProvider).valueOrNull;
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;
    final cfg = ref.watch(settingsProvider).valueOrNull;
    final mode = ref.watch(themeModeProvider);
    final current = Localizations.localeOf(context).languageCode;

    Widget section(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s4, Space.s24, Space.s4, Space.s8),
              child: Text(title, style: text.titleSmall?.copyWith(color: p.textMuted)),
            ),
            Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: p.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: children),
            ),
          ],
        );

    Widget tile(IconData icon, String title, {VoidCallback? onTap, Widget? trailing, Color? color}) => ListTile(
          minVerticalPadding: Space.s12,
          leading: Icon(icon, color: color ?? p.textMuted),
          title: Text(title, style: text.bodyLarge?.copyWith(color: color)),
          trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
          onTap: onTap,
        );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Space.s24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Layout.formWidth * 1.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.settingsTitle, style: text.headlineMedium),
                  if (me != null)
                    section(l.account, [
                      tile(Icons.person_outline_rounded, me.name,
                          trailing: Text(l.role(me.role), style: text.bodySmall)),
                      tile(Icons.edit_outlined, l.editProfile,
                          onTap: () => showEditProfileSheet(context, me)),
                    ]),
                  section(l.language, [
                    for (final entry in languageNames.entries)
                      RadioListTile<String>(
                        value: entry.key,
                        groupValue: current,
                        title: Text(entry.value),
                        onChanged: (v) {
                          if (v != null) ref.read(localeProvider.notifier).set(Locale(v));
                        },
                      ),
                  ]),
                  section(l.theme, [
                    for (final option in [
                      (ThemeMode.system, l.themeSystem),
                      (ThemeMode.light, l.themeLight),
                      (ThemeMode.dark, l.themeDark),
                    ])
                      RadioListTile<ThemeMode>(
                        value: option.$1,
                        groupValue: mode,
                        title: Text(option.$2),
                        onChanged: (v) {
                          if (v != null) ref.read(themeModeProvider.notifier).set(v);
                        },
                      ),
                  ]),
                  if (cfg != null && cfg.hasContact)
                    section(l.contactTitle, [
                      if (cfg.contactPhone.isNotEmpty) tile(Icons.call_outlined, cfg.contactPhone),
                      if (cfg.contactEmail.isNotEmpty) tile(Icons.mail_outline_rounded, cfg.contactEmail),
                    ]),
                  section(l.legal, [
                    tile(Icons.description_outlined, l.termsOfUse, onTap: () => context.push('/legal/terms')),
                    tile(Icons.privacy_tip_outlined, l.privacyPolicy, onTap: () => context.push('/legal/privacy')),
                  ]),
                  if (me != null)
                    section(l.yourData, [
                      tile(Icons.download_outlined, l.exportData, onTap: () => showExportDataSheet(context, me)),
                      tile(Icons.delete_outline_rounded, l.deleteAccount,
                          color: p.error, onTap: () => showDeleteAccountDialog(context)),
                    ]),
                  if (signedIn)
                    section('', [
                      tile(Icons.logout_rounded, l.signOut,
                          onTap: () => ref.read(authRepositoryProvider).signOut()),
                    ])
                  else
                    section('', [
                      tile(Icons.login_rounded, l.signIn, onTap: () => context.go('/sign-in')),
                    ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.s32),
                    child: Column(
                      children: [
                        Image.asset('assets/brand/logo.png', width: 40, height: 40),
                        const SizedBox(height: Space.s8),
                        Text('${l.appName}  ·  ${l.versionLabel(appVersion)}', style: text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
