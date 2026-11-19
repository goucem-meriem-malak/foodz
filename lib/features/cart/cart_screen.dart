import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/cart.dart';
import '../../data/providers.dart';
import '../orders/order_widgets.dart';

void _leave(BuildContext context) => context.canPop() ? context.pop() : context.go('/home');

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final lines = ref.watch(cartProvider);
    final cfg = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;

    final subtotal = cartSubtotal(lines);
    final belowMin = subtotal < cfg.minOrder;
    final canCheckout = cfg.openNow() && !belowMin;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.cartTitle),
        leading: BackButton(onPressed: () => _leave(context)),
        actions: [
          if (lines.isNotEmpty)
            TextButton(onPressed: () => ref.read(cartProvider.notifier).clear(), child: Text(l.clearCart)),
        ],
      ),
      body: lines.isEmpty
          ? StateView(
              icon: Icons.shopping_bag_outlined,
              title: l.cartEmptyTitle,
              message: l.cartEmptyBody,
              actionLabel: l.backToMenu,
              onAction: () => _leave(context),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(Space.s24),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: Layout.formWidth * 1.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final line in lines) ...[
                            AppCard(
                              padding: const EdgeInsets.all(Space.s12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(line.name.of(lang), style: text.titleMedium),
                                        if (line.chosen.isNotEmpty)
                                          Text(
                                            line.chosen.map((c) => c.name.of(lang)).join(' · '),
                                            style: text.bodySmall?.copyWith(color: p.textMuted),
                                          ),
                                        const SizedBox(height: Space.s8),
                                        Text(Fmt.money(line.total, lang),
                                            style: text.titleSmall?.copyWith(color: p.primary)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l.decrease,
                                    onPressed: () => ref.read(cartProvider.notifier).setQty(line.key, line.qty - 1),
                                    icon: Icon(line.qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded),
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(Fmt.number(line.qty, lang),
                                        textAlign: TextAlign.center, style: text.titleMedium),
                                  ),
                                  IconButton(
                                    tooltip: l.increase,
                                    onPressed: line.qty < maxQtyPerLine
                                        ? () => ref.read(cartProvider.notifier).setQty(line.key, line.qty + 1)
                                        : null,
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: Space.s12),
                          ],
                          const SizedBox(height: Space.s12),
                          AppCard(
                            child: Column(
                              children: [
                                PriceRow(l.subtotal, Fmt.money(subtotal, lang)),
                                PriceRow(l.deliveryFee, Fmt.money(cfg.deliveryFee, lang)),
                                const Divider(),
                                PriceRow(l.total, Fmt.money(subtotal + cfg.deliveryFee, lang), bold: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.s16),
                          if (!cfg.openNow())
                            StatusBanner(message: l.closedBanner, kind: BannerKind.error)
                          else if (belowMin)
                            StatusBanner(message: l.minOrderNotice(Fmt.money(cfg.minOrder, lang))),
                          const SizedBox(height: Space.s16),
                          AppButton(
                            label: signedIn ? l.checkout : l.signInToOrder,
                            onPressed: !signedIn
                                ? () => context.go('/sign-in')
                                : (canCheckout ? () => context.push('/checkout') : null),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
