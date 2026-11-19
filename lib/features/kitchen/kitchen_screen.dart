import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_list.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/order.dart';
import '../../data/providers.dart';
import '../orders/order_widgets.dart';

const _prepChoices = [10, 20, 30, 45, 60];

/// Chef screen. Shows only what the kitchen needs (dishes, extras, note), never
/// the customer's name, phone or address. Updates live.
class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final orders = ref.watch(kitchenOrdersProvider);

    ref.listen<AsyncValue<List<Order>>>(kitchenOrdersProvider, (prev, next) {
      if (prev == null || !prev.hasValue || !next.hasValue) return;
      final before = prev.value!.map((o) => o.id).toSet();
      final fresh = next.value!.where((o) => o.status == OrderStatus.confirmed && !before.contains(o.id));
      if (fresh.isEmpty) return;
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.newKitchenOrder(fresh.first.code))));
    });

    return PageList(
      title: l.navKitchen,
      children: [
        orders.when(
          loading: () => const ListSkeleton(),
          error: (_, __) => StateView(
            icon: Icons.cloud_off_rounded,
            isError: true,
            title: l.somethingWrongTitle,
            message: l.errNetwork,
            actionLabel: l.retry,
            onAction: () => ref.invalidate(kitchenOrdersProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return StateView(icon: Icons.soup_kitchen_outlined, title: l.kitchenEmptyTitle, message: l.kitchenEmptyBody);
            }
            Widget group(String title, OrderStatus s) {
              final items = list.where((o) => o.status == s).toList();
              if (items.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionLabel(title),
                  for (final o in items) ...[
                    _KitchenCard(order: o),
                    const SizedBox(height: Space.s12),
                  ],
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                group(l.kitchenToCook, OrderStatus.confirmed),
                group(l.kitchenCooking, OrderStatus.preparing),
                group(l.kitchenReady, OrderStatus.ready),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KitchenCard extends ConsumerStatefulWidget {
  const _KitchenCard({required this.order});
  final Order order;

  @override
  ConsumerState<_KitchenCard> createState() => _KitchenCardState();
}

class _KitchenCardState extends ConsumerState<_KitchenCard> {
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

  Future<void> _start() async {
    final l = context.l10n;
    final cfg = ref.read(settingsProvider).valueOrNull ?? AppSettings.defaults;
    var minutes = _prepChoices.contains(cfg.defaultPrepMinutes) ? cfg.defaultPrepMinutes : 20;
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l.prepTimeTitle),
          content: Wrap(
            spacing: Space.s8,
            runSpacing: Space.s8,
            children: [
              for (final m in _prepChoices)
                ChoiceChip(
                  label: Text(l.minutesShort(m)),
                  selected: minutes == m,
                  onSelected: (_) => setLocal(() => minutes = m),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, minutes), child: Text(l.startCooking)),
          ],
        ),
      ),
    );
    if (chosen != null) await _run(() => ref.read(ordersRepositoryProvider).startCooking(widget.order.id, chosen));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final o = widget.order;
    final eta = o.expectedReadyAt;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('#${o.code}', style: text.titleLarge)),
              if (eta != null)
                Text(l.readyAround(shortTime(eta)), style: text.labelMedium?.copyWith(color: p.primary)),
            ],
          ),
          const SizedBox(height: Space.s12),
          OrderLinesView(lines: o.lines, lang: lang, showPrices: false, large: true),
          if (o.note.isNotEmpty) ...[
            const SizedBox(height: Space.s8),
            Text('${l.noteLabel}: ${o.note}', style: text.bodyMedium?.copyWith(color: p.warning)),
          ],
          const SizedBox(height: Space.s12),
          if (o.status == OrderStatus.confirmed)
            AppButton(label: l.startCooking, icon: Icons.local_fire_department_rounded, loading: _busy, onPressed: _start),
          if (o.status == OrderStatus.preparing)
            AppButton(
              label: l.markReady,
              icon: Icons.check_circle_rounded,
              loading: _busy,
              onPressed: () => _run(() => ref.read(ordersRepositoryProvider).markReady(o.id)),
            ),
          if (o.status == OrderStatus.ready)
            Text(l.waitingForPickup, style: text.bodyMedium?.copyWith(color: p.textMuted)),
        ],
      ),
    );
  }
}
