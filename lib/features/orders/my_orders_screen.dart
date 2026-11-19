import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_list.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/order.dart';
import '../../data/providers.dart';
import 'order_widgets.dart';

/// The customer's orders, newest first. Tap one to follow it.
class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;

    if (!signedIn) {
      return SafeArea(
        child: StateView(
          icon: Icons.receipt_long_outlined,
          title: l.signInToSeeOrders,
          message: l.ordersEmptyBody,
          actionLabel: l.signIn,
          onAction: () => context.go('/sign-in'),
        ),
      );
    }

    final orders = ref.watch(myOrdersProvider);
    return PageList(
      title: l.ordersTitle,
      children: [
        orders.when(
          loading: () => const ListSkeleton(),
          error: (_, __) => StateView(
            icon: Icons.cloud_off_rounded,
            isError: true,
            title: l.somethingWrongTitle,
            message: l.errNetwork,
            actionLabel: l.retry,
            onAction: () => ref.invalidate(myOrdersProvider),
          ),
          data: (list) => list.isEmpty
              ? StateView(icon: Icons.receipt_long_outlined, title: l.ordersEmptyTitle, message: l.ordersEmptyBody)
              : Column(
                  children: [
                    for (final o in list) ...[
                      OrderTile(order: o),
                      const SizedBox(height: Space.s12),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Summary card of one order, used in the customer list and the admin history.
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, this.onTap});
  final Order order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final lang = Localizations.localeOf(context).languageCode;
    final summary = order.lines.map((e) => '${Fmt.number(e.qty, lang)}× ${e.name.of(lang)}').join(', ');
    return AppCard(
      onTap: onTap ?? () => context.push('/order/${order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.orderNumber(order.code), style: text.titleMedium)),
              StatusChip(order.status),
            ],
          ),
          const SizedBox(height: Space.s4),
          Text(shortDateTime(order.createdAt), style: text.bodySmall?.copyWith(color: p.textMuted)),
          const SizedBox(height: Space.s8),
          Text(summary, style: text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: Space.s8),
          Text(Fmt.money(order.total, lang), style: text.titleSmall?.copyWith(color: p.primary)),
        ],
      ),
    );
  }
}
