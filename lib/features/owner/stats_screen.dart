import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/sales_stats.dart';
import '../../data/providers.dart';

/// Delivered orders over the last [days] days (1 = today), counted from midnight.
final salesStatsProvider = FutureProvider.autoDispose.family<SalesStats, int>((ref, days) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final since = today.subtract(Duration(days: days <= 1 ? 0 : days - 1));
  final orders = await ref.watch(ordersRepositoryProvider).deliveredSince(since);
  return SalesStats.from(orders);
});

/// Owner only: orders delivered, revenue, average order and best-selling dishes.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _days = 1;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final stats = ref.watch(salesStatsProvider(_days));

    Widget number(String label, String value) => AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.bodyMedium?.copyWith(color: p.textMuted)),
              const SizedBox(height: Space.s4),
              Text(value, style: text.headlineSmall),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.statsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.s24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Layout.maxContent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 1, label: Text(l.statsToday)),
                        ButtonSegment(value: 7, label: Text(l.stats7)),
                        ButtonSegment(value: 30, label: Text(l.stats30)),
                      ],
                      selected: {_days},
                      onSelectionChanged: (s) => setState(() => _days = s.first),
                    ),
                    const SizedBox(height: Space.s16),
                    stats.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(Space.s32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => StateView(
                        icon: Icons.cloud_off_rounded,
                        title: l.somethingWrongTitle,
                        message: l.errNetwork,
                        actionLabel: l.retry,
                        onAction: () => ref.invalidate(salesStatsProvider(_days)),
                      ),
                      data: (s) => s.orders == 0
                          ? StateView(icon: Icons.insights_rounded, title: l.statsNoData)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                number(l.statsOrders, Fmt.number(s.orders, lang)),
                                const SizedBox(height: Space.s12),
                                number(l.statsRevenue, Fmt.money(s.revenue, lang)),
                                const SizedBox(height: Space.s12),
                                number(l.statsAverage, Fmt.money(s.average, lang)),
                                const SizedBox(height: Space.s24),
                                Text(l.statsTopDishes, style: text.titleMedium),
                                const SizedBox(height: Space.s8),
                                for (final d in s.top)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: Space.s8),
                                    child: AppCard(
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(d.name.of(lang), style: text.titleSmall)),
                                          Text('× ${Fmt.number(d.qty, lang)}', style: text.titleSmall),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: Space.s16),
                    Text(l.statsNote, style: text.bodySmall?.copyWith(color: p.textMuted)),
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
