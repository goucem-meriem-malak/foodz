import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/language_menu.dart';
import '../../core/widgets/page_list.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/localized.dart';
import '../../data/models/menu.dart';
import '../../data/providers.dart';
import '../menu/menu_screen.dart' show DishPhoto;

/// Admin and owner: add, edit, hide and sell out dishes and categories.
class MenuManagerScreen extends ConsumerWidget {
  const MenuManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final cats = ref.watch(categoriesProvider);
    final dishes = ref.watch(dishesProvider);

    if (cats.isLoading || dishes.isLoading) {
      return PageList(title: l.navMenu, children: const [ListSkeleton()]);
    }
    if (cats.hasError || dishes.hasError) {
      return SafeArea(
        child: StateView(
          icon: Icons.lock_outline_rounded,
          isError: true,
          title: l.somethingWrongTitle,
          message: l.errNetwork,
          actionLabel: l.retry,
          onAction: () {
            ref.invalidate(categoriesProvider);
            ref.invalidate(dishesProvider);
          },
        ),
      );
    }

    final categories = cats.value ?? const <MenuCategory>[];
    final all = dishes.value ?? const <Dish>[];
    final known = categories.map((c) => c.id).toSet();
    final orphans = all.where((d) => !known.contains(d.categoryId)).toList();

    void addDish() {
      if (categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.addCategoryFirst)));
      } else {
        context.push('/dish-editor/new');
      }
    }

    Widget dishRow(Dish d) => Padding(
          padding: const EdgeInsets.only(bottom: Space.s8),
          child: AppCard(
            padding: const EdgeInsets.all(Space.s8),
            onTap: () => context.push('/dish-editor/${d.id}'),
            child: Row(
              children: [
                DishPhoto(url: d.imageUrl, size: 56),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name.of(lang), style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(Fmt.money(d.price, lang), style: text.bodySmall?.copyWith(color: p.textMuted)),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: d.available,
                      onChanged: (v) async {
                        try {
                          await ref.read(menuRepositoryProvider).setAvailable(d.id, v);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errGeneric)));
                          }
                        }
                      },
                    ),
                    Text(d.available ? l.availableShort : l.soldOut,
                        style: text.labelSmall?.copyWith(color: d.available ? p.success : p.error)),
                  ],
                ),
              ],
            ),
          ),
        );

    return PageList(
      title: l.navMenu,
      action: AppButton(label: l.addDish, icon: Icons.add_rounded, expand: false, onPressed: addDish),
      children: [
        SectionLabel(l.categoriesTitle),
        Wrap(
          spacing: Space.s8,
          runSpacing: Space.s8,
          children: [
            for (final c in categories)
              InputChip(
                label: Text(c.active ? c.name.of(lang) : '${c.name.of(lang)} · ${l.hiddenTag}'),
                onPressed: () => showCategoryDialog(context, ref, c, categories.length + 1, all.any((d) => d.categoryId == c.id)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: Text(l.addCategory),
              onPressed: () => showCategoryDialog(context, ref, null, categories.length + 1, false),
            ),
          ],
        ),
        if (all.isEmpty && categories.isNotEmpty)
          StateView(icon: Icons.restaurant_menu_rounded, title: l.noDishesTitle, message: l.noDishesBody),
        for (final c in categories)
          if (all.any((d) => d.categoryId == c.id)) ...[
            SectionLabel(c.name.of(lang)),
            for (final d in all.where((d) => d.categoryId == c.id)) dishRow(d),
          ],
        if (orphans.isNotEmpty) ...[
          SectionLabel(l.uncategorized),
          for (final d in orphans) dishRow(d),
        ],
      ],
    );
  }
}

Future<void> showCategoryDialog(
  BuildContext context,
  WidgetRef ref,
  MenuCategory? existing,
  int nextOrder,
  bool hasDishes,
) async {
  final l = context.l10n;
  final controllers = {
    for (final code in languageNames.keys)
      code: TextEditingController(
        text: existing == null
            ? ''
            : switch (code) {
                'ar' => existing.name.ar,
                'fr' => existing.name.fr,
                _ => existing.name.en,
              },
      ),
  };
  var active = existing?.active ?? true;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing == null ? l.addCategory : l.editCategory),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in languageNames.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s8),
                  child: TextField(
                    controller: controllers[e.key],
                    maxLength: 80,
                    decoration: InputDecoration(labelText: l.fieldName(e.value), counterText: ''),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.categoryVisible),
                value: active,
                onChanged: (v) => setLocal(() => active = v),
              ),
              if (error != null) Text(error!, style: TextStyle(color: ctx.palette.error)),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: hasDishes
                  ? () => setLocal(() => error = l.categoryHasDishes)
                  : () async {
                      try {
                        await ref.read(menuRepositoryProvider).deleteCategory(existing.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        setLocal(() => error = l.errGeneric);
                      }
                    },
              child: Text(l.delete, style: TextStyle(color: ctx.palette.error)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          TextButton(
            onPressed: () async {
              final name = Localized(
                ar: controllers['ar']!.text.trim(),
                fr: controllers['fr']!.text.trim(),
                en: controllers['en']!.text.trim(),
              );
              if (name.isEmpty) {
                setLocal(() => error = l.errRequired);
                return;
              }
              try {
                await ref.read(menuRepositoryProvider).saveCategory(
                      MenuCategory(id: existing?.id ?? '', name: name, order: existing?.order ?? nextOrder, active: active),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
                setLocal(() => error = l.errGeneric);
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
  for (final c in controllers.values) {
    c.dispose();
  }
}
