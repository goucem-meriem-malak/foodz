import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/page_list.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/cart.dart';
import '../../data/models/menu.dart';
import '../../data/providers.dart';
import '../home/verify_banner.dart';
import 'dish_sheet.dart';

/// What customers (and guests) see first: the menu, by category, with a cart bar.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;

    final auth = ref.watch(authStateProvider);
    final signedIn = auth.valueOrNull != null;
    final me = ref.watch(appUserProvider).valueOrNull;
    final verified = ref.watch(emailVerifiedProvider);
    final cfg = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final cats = ref.watch(categoriesProvider);
    final dishes = ref.watch(dishesProvider);
    final cart = ref.watch(cartProvider);

    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 1000 ? 3 : (width >= 640 ? 2 : 1);
    final contentWidth = math.min(width, Layout.maxContent) - 2 * Space.s24;
    final cardWidth = (contentWidth - (cols - 1) * Space.s12) / cols;

    Widget body;
    if (cats.isLoading || dishes.isLoading) {
      body = const ListSkeleton(count: 4, height: 120);
    } else if (cats.hasError || dishes.hasError) {
      body = StateView(
        icon: Icons.cloud_off_rounded,
        isError: true,
        title: l.somethingWrongTitle,
        message: l.errNetwork,
        actionLabel: l.retry,
        onAction: () {
          ref.invalidate(categoriesProvider);
          ref.invalidate(dishesProvider);
        },
      );
    } else {
      final categories = (cats.valueOrNull ?? const <MenuCategory>[]).where((c) => c.active).toList();
      final all = dishes.valueOrNull ?? const <Dish>[];
      final shownCats = categories.where((c) => _categoryId == null || c.id == _categoryId).toList();
      final visible = [
        for (final c in shownCats) (c, all.where((d) => d.categoryId == c.id).toList()),
      ].where((e) => e.$2.isNotEmpty).toList();

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryChip(label: l.allCategories, selected: _categoryId == null, onTap: () => setState(() => _categoryId = null)),
                  for (final c in categories)
                    _CategoryChip(
                      label: c.name.of(lang),
                      selected: _categoryId == c.id,
                      onTap: () => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
            ),
          if (visible.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: Space.s24),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: p.outline),
              ),
              child: StateView(
                icon: Icons.restaurant_menu_rounded,
                title: l.menuEmptyTitle,
                message: l.menuEmptyBody,
              ),
            ),
          for (final entry in visible) ...[
            Padding(
              padding: const EdgeInsets.only(top: Space.s24, bottom: Space.s12),
              child: Text(entry.$1.name.of(lang), style: text.titleLarge),
            ),
            Wrap(
              spacing: Space.s12,
              runSpacing: Space.s12,
              children: [
                for (final dish in entry.$2)
                  SizedBox(
                    width: cardWidth,
                    child: _DishCard(
                      dish: dish,
                      lang: lang,
                      onTap: () => showDishSheet(context, dish, canOrder: cfg.openNow()),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
    }

    final list = PageList(
      title: me == null ? l.homeGreetingGuest : l.homeGreeting(me.name.split(' ').first),
      bottomSpace: cart.isEmpty ? Space.s24 : 112,
      children: [
        if (signedIn && !verified) ...[
          const FadeSlideIn(child: VerifyBanner()),
          const SizedBox(height: Space.s16),
        ],
        if (!cfg.openNow()) ...[
          StatusBanner(message: l.closedBanner, kind: BannerKind.error),
          const SizedBox(height: Space.s16),
        ],
        if (!signedIn) ...[
          StatusBanner(
            message: l.guestBanner,
            action: AppButton(label: l.signIn, expand: false, kind: AppButtonKind.secondary, onPressed: () => context.go('/sign-in')),
          ),
          const SizedBox(height: Space.s16),
        ],
        body,
        if (cfg.hasContact) ...[
          const SizedBox(height: Space.s32),
          Text(l.contactTitle, style: text.titleSmall),
          const SizedBox(height: Space.s4),
          Text(
            [cfg.contactPhone, cfg.contactEmail].where((s) => s.isNotEmpty).join('  ·  '),
            style: text.bodyMedium?.copyWith(color: p.textMuted),
            textDirection: TextDirection.ltr,
          ),
        ],
      ],
    );

    return Stack(
      children: [
        list,
        if (cart.isNotEmpty)
          Positioned(
            left: Space.s16,
            right: Space.s16,
            bottom: Space.s16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Layout.formWidth),
                child: AppButton(
                  icon: Icons.shopping_bag_rounded,
                  label: l.cartBar(cartCount(cart), Fmt.money(cartSubtotal(cart), lang)),
                  onPressed: () => context.push('/cart'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Space.s8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: context.palette.primary,
        labelStyle: TextStyle(
          color: selected ? context.palette.onPrimary : context.palette.text,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: context.palette.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, required this.lang, required this.onTap});
  final Dish dish;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final desc = dish.description.of(lang);
    return Opacity(
      opacity: dish.available ? 1 : 0.55,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Space.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name.of(lang), style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: Space.s4),
                    Text(desc, style: text.bodySmall?.copyWith(color: p.textMuted), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: Space.s12),
                  Row(
                    children: [
                      Text(Fmt.money(dish.price, lang), style: text.titleSmall?.copyWith(color: p.primary)),
                      if (!dish.available) ...[
                        const SizedBox(width: Space.s8),
                        Text(l.soldOut, style: text.labelMedium?.copyWith(color: p.error, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s12),
            DishPhoto(url: dish.imageUrl, size: 96),
          ],
        ),
      ),
    );
  }
}

/// Dish picture, or a neutral tile when there is none or it cannot load.
class DishPhoto extends StatelessWidget {
  const DishPhoto({super.key, required this.url, required this.size});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fallback = Container(
      width: size,
      height: size,
      color: p.surfaceTonal,
      child: Icon(Icons.restaurant_rounded, color: p.textMuted, size: size / 3),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}
