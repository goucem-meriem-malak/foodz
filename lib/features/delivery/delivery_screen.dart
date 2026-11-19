import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/phone.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_list.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/order.dart';
import '../../data/providers.dart';
import '../orders/my_orders_screen.dart' show OrderTile;
import '../orders/order_widgets.dart';

/// Delivery person screen: orders coming up (with the preparation time, so they
/// can get ready), orders ready to take, and the ones they are delivering.
class DeliveryScreen extends ConsumerWidget {
  const DeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final board = ref.watch(courierBoardProvider);
    final mine = ref.watch(courierMineProvider);

    ref.listen<AsyncValue<List<Order>>>(courierBoardProvider, (prev, next) {
      if (prev == null || !prev.hasValue || !next.hasValue) return;
      final before = prev.value!.where((o) => o.status == OrderStatus.ready).map((o) => o.id).toSet();
      final fresh = next.value!.where((o) => o.status == OrderStatus.ready && !before.contains(o.id));
      if (fresh.isEmpty) return;
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.orderReadyAlert(fresh.first.code))));
    });

    if (board.isLoading || mine.isLoading) {
      return PageList(title: l.navDeliveries, children: const [ListSkeleton()]);
    }
    if (board.hasError || mine.hasError) {
      return SafeArea(
        child: StateView(
          icon: Icons.cloud_off_rounded,
          isError: true,
          title: l.somethingWrongTitle,
          message: l.errNetwork,
          actionLabel: l.retry,
          onAction: () {
            ref.invalidate(courierBoardProvider);
            ref.invalidate(courierMineProvider);
          },
        ),
      );
    }

    final upcoming = (board.value ?? const <Order>[]).where((o) => o.status != OrderStatus.ready).toList();
    final ready = (board.value ?? const <Order>[]).where((o) => o.status == OrderStatus.ready).toList();
    final onMyWay = (mine.value ?? const <Order>[]).where((o) => o.status == OrderStatus.outForDelivery).toList();
    final done = (mine.value ?? const <Order>[]).where((o) => o.status == OrderStatus.delivered).take(5).toList();

    Widget group(String title, List<Order> orders, Widget Function(Order) card) {
      if (orders.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title),
          for (final o in orders) ...[card(o), const SizedBox(height: Space.s12)],
        ],
      );
    }

    final nothing = upcoming.isEmpty && ready.isEmpty && onMyWay.isEmpty && done.isEmpty;

    return PageList(
      title: l.navDeliveries,
      children: [
        if (nothing) StateView(icon: Icons.delivery_dining_outlined, title: l.deliveryEmptyTitle, message: l.deliveryEmptyBody),
        group(l.deliveryOnMyWay, onMyWay, (o) => _MyDeliveryCard(order: o)),
        group(l.deliveryReadyNow, ready, (o) => _TakeCard(order: o, uid: uid)),
        group(l.deliveryUpcoming, upcoming, (o) => _UpcomingCard(order: o)),
        group(l.deliveryDone, done, (o) => OrderTile(order: o)),
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final eta = order.expectedReadyAt;
    final status = order.status == OrderStatus.preparing && eta != null
        ? l.readyAroundMinutes(shortTime(eta), order.prepMinutes ?? 0)
        : l.incomingConfirmed;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('#${order.code}', style: text.titleMedium)),
              Text(order.area, style: text.bodySmall?.copyWith(color: p.textMuted)),
            ],
          ),
          const SizedBox(height: Space.s4),
          Text(status, style: text.bodyMedium?.copyWith(color: p.primary)),
          const SizedBox(height: Space.s8),
          OrderLinesView(lines: order.lines, lang: lang, showPrices: false),
        ],
      ),
    );
  }
}

class _TakeCard extends ConsumerStatefulWidget {
  const _TakeCard({required this.order, required this.uid});
  final Order order;
  final String uid;

  @override
  ConsumerState<_TakeCard> createState() => _TakeCardState();
}

class _TakeCardState extends ConsumerState<_TakeCard> {
  bool _busy = false;

  Future<void> _take() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).takeDelivery(widget.order.id, widget.uid);
    } catch (_) {
      // Another delivery person may have taken it first.
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.takeFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final o = widget.order;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('#${o.code}', style: text.titleMedium)),
              Text(o.area, style: text.bodySmall?.copyWith(color: p.textMuted)),
            ],
          ),
          const SizedBox(height: Space.s8),
          OrderLinesView(lines: o.lines, lang: lang, showPrices: false),
          const SizedBox(height: Space.s8),
          Text(l.collectCash(Fmt.money(o.total, lang)), style: text.bodyMedium?.copyWith(color: p.primary)),
          const SizedBox(height: Space.s12),
          AppButton(label: l.takeDelivery, icon: Icons.delivery_dining_rounded, loading: _busy, onPressed: _take),
        ],
      ),
    );
  }
}

class _MyDeliveryCard extends ConsumerStatefulWidget {
  const _MyDeliveryCard({required this.order});
  final Order order;

  @override
  ConsumerState<_MyDeliveryCard> createState() => _MyDeliveryCardState();
}

class _MyDeliveryCardState extends ConsumerState<_MyDeliveryCard> {
  bool _busy = false;

  Future<void> _delivered() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).markDelivered(widget.order.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errGeneric)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final o = widget.order;
    final contact = ref.watch(contactProvider(o.id)).valueOrNull;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('#${o.code}', style: text.titleMedium),
          const SizedBox(height: Space.s8),
          if (contact != null) ...[
            Text(contact.name, style: text.bodyLarge),
            Text('${o.area} · ${contact.address}', style: text.bodyMedium),
            const SizedBox(height: Space.s8),
            AppButton(
              label: contact.phone,
              icon: Icons.call_rounded,
              kind: AppButtonKind.secondary,
              onPressed: () => callPhone(context, contact.phone),
            ),
            const SizedBox(height: Space.s12),
          ],
          OrderLinesView(lines: o.lines, lang: lang, showPrices: false),
          const SizedBox(height: Space.s8),
          Text(l.collectCash(Fmt.money(o.total, lang)), style: text.titleSmall?.copyWith(color: p.primary)),
          const SizedBox(height: Space.s12),
          AppButton(label: l.markDelivered, icon: Icons.check_circle_rounded, loading: _busy, onPressed: _delivered),
        ],
      ),
    );
  }
}
