import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/phone.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/order.dart';
import '../../data/models/user_role.dart';
import '../../data/providers.dart';
import '../orders/my_orders_screen.dart';
import '../orders/order_widgets.dart';

/// Live board for admins and the owner: new orders to confirm by phone,
/// orders in progress, and history. Updates in real time.
class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final open = ref.watch(openOrdersProvider);

    // Alert when a new order arrives while the board is open.
    ref.listen<AsyncValue<List<Order>>>(openOrdersProvider, (prev, next) {
      if (prev == null || !prev.hasValue || !next.hasValue) return;
      final before = prev.value!.where((o) => o.status == OrderStatus.placed).map((o) => o.id).toSet();
      final fresh = next.value!.where((o) => o.status == OrderStatus.placed && !before.contains(o.id));
      if (fresh.isEmpty) return;
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.newOrderAlert(fresh.first.code))));
    });

    final list = open.valueOrNull ?? const <Order>[];
    final fresh = list.where((o) => o.status == OrderStatus.placed).toList();
    final progress = list.where((o) => o.status != OrderStatus.placed).toList();

    return DefaultTabController(
      length: 3,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s24, Space.s24, Space.s24, Space.s8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(l.navOrders, style: Theme.of(context).textTheme.headlineMedium),
              ),
            ),
            TabBar(
              tabs: [
                Tab(
                  child: Badge(
                    isLabelVisible: fresh.isNotEmpty,
                    label: Text('${fresh.length}'),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: Space.s8), child: Text(l.tabNew)),
                  ),
                ),
                Tab(text: l.tabInProgress),
                Tab(text: l.tabHistory),
              ],
            ),
            Expanded(
              child: open.hasError
                  ? StateView(
                      icon: Icons.cloud_off_rounded,
                      isError: true,
                      title: l.somethingWrongTitle,
                      message: l.errNetwork,
                      actionLabel: l.retry,
                      onAction: () => ref.invalidate(openOrdersProvider),
                    )
                  : TabBarView(
                      children: [
                        _OrderList(orders: fresh, loading: open.isLoading, empty: l.noNewOrders),
                        _OrderList(orders: progress, loading: open.isLoading, empty: l.noActiveOrders),
                        const _HistoryList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.loading, required this.empty});
  final List<Order> orders;
  final bool loading;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (!loading && orders.isEmpty) {
      return StateView(icon: Icons.inbox_outlined, title: empty);
    }
    return ListView(
      padding: const EdgeInsets.all(Space.s24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Layout.formWidth * 1.4),
            child: Column(
              children: [
                for (final o in orders) ...[
                  AdminOrderCard(order: o),
                  const SizedBox(height: Space.s16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final history = ref.watch(historyOrdersProvider);
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => StateView(
        icon: Icons.cloud_off_rounded,
        isError: true,
        title: l.somethingWrongTitle,
        message: l.errNetwork,
        actionLabel: l.retry,
        onAction: () => ref.invalidate(historyOrdersProvider),
      ),
      data: (list) => list.isEmpty
          ? StateView(icon: Icons.history_rounded, title: l.noHistory)
          : ListView(
              padding: const EdgeInsets.all(Space.s24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: Layout.formWidth * 1.4),
                    child: Column(
                      children: [
                        for (final o in list) ...[
                          OrderTile(order: o),
                          const SizedBox(height: Space.s12),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class AdminOrderCard extends ConsumerStatefulWidget {
  const AdminOrderCard({super.key, required this.order});
  final Order order;

  @override
  ConsumerState<AdminOrderCard> createState() => _AdminOrderCardState();
}

class _AdminOrderCardState extends ConsumerState<AdminOrderCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errGeneric)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final l = context.l10n;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(l.rejectTitle),
            content: TextField(
              controller: controller,
              maxLength: 200,
              autofocus: true,
              decoration: InputDecoration(hintText: l.rejectHint, errorText: error),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
              TextButton(
                onPressed: () {
                  final v = controller.text.trim();
                  if (v.isEmpty) {
                    setLocal(() => error = l.errRequired);
                  } else {
                    Navigator.pop(ctx, v);
                  }
                },
                child: Text(l.rejectOrder),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (reason != null) await _run(() => ref.read(ordersRepositoryProvider).reject(widget.order, reason));
  }

  Future<void> _assign() async {
    final l = context.l10n;
    final couriers = (ref.read(teamProvider).valueOrNull ?? const [])
        .where((u) => u.role == UserRole.delivery && !u.blocked)
        .toList();
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.assignCourier),
        children: couriers.isEmpty
            ? [Padding(padding: const EdgeInsets.all(Space.s24), child: Text(l.noCouriers))]
            : [
                for (final c in couriers)
                  SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c.uid), child: Text(c.name)),
              ],
      ),
    );
    if (chosen != null) await _run(() => ref.read(ordersRepositoryProvider).assignCourier(widget.order.id, chosen));
  }

  Future<void> _cancel() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cancelOrderTitle),
        content: Text(l.cancelByStaffBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.keepOrder)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.yesCancel)),
        ],
      ),
    );
    if (ok == true) await _run(() => ref.read(ordersRepositoryProvider).adminCancel(widget.order.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final o = widget.order;
    final adminUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final contact = ref.watch(contactProvider(o.id)).valueOrNull;
    final repo = ref.read(ordersRepositoryProvider);

    final actions = <Widget>[
      if (o.status == OrderStatus.placed) ...[
        AppButton(
          label: l.confirmOrder,
          expand: false,
          icon: Icons.check_rounded,
          loading: _busy,
          onPressed: () => _run(() => repo.confirm(o, adminUid)),
        ),
        AppButton(label: l.rejectOrder, expand: false, kind: AppButtonKind.secondary, onPressed: _busy ? null : _reject),
      ],
      if (o.status == OrderStatus.ready)
        AppButton(label: l.assignCourier, expand: false, kind: AppButtonKind.secondary, onPressed: _busy ? null : _assign),
      if (o.status == OrderStatus.outForDelivery)
        AppButton(
          label: l.markDelivered,
          expand: false,
          loading: _busy,
          onPressed: () => _run(() => repo.markDelivered(o.id)),
        ),
      if (o.status != OrderStatus.placed && !o.status.isFinal)
        AppButton(label: l.cancelOrderButton, expand: false, kind: AppButtonKind.text, onPressed: _busy ? null : _cancel),
    ];

    return AppCard(
      onTap: () => context.push('/order/${o.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.orderNumber(o.code), style: text.titleMedium)),
              StatusChip(o.status),
            ],
          ),
          const SizedBox(height: Space.s4),
          Text(shortDateTime(o.createdAt), style: text.bodySmall?.copyWith(color: p.textMuted)),
          const SizedBox(height: Space.s12),
          if (contact != null) ...[
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 18, color: p.textMuted),
                const SizedBox(width: Space.s8),
                Expanded(child: Text(contact.name, style: text.bodyLarge)),
                TextButton.icon(
                  onPressed: () => callPhone(context, contact.phone),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text(contact.phone, textDirection: TextDirection.ltr),
                ),
              ],
            ),
            Text('${o.area} · ${contact.address}', style: text.bodySmall?.copyWith(color: p.textMuted)),
            const SizedBox(height: Space.s12),
          ],
          OrderLinesView(lines: o.lines, lang: lang, showPrices: false),
          if (o.note.isNotEmpty) ...[
            const SizedBox(height: Space.s8),
            Text('${l.noteLabel}: ${o.note}', style: text.bodySmall?.copyWith(color: p.textMuted)),
          ],
          const SizedBox(height: Space.s12),
          Text(Fmt.money(o.total, lang), style: text.titleSmall?.copyWith(color: p.primary)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: Space.s12),
            Wrap(spacing: Space.s8, runSpacing: Space.s8, children: actions),
          ],
        ],
      ),
    );
  }
}
