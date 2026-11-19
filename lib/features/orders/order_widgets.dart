import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/models/order.dart';

String statusLabel(AppLocalizations l, OrderStatus s) => switch (s) {
      OrderStatus.placed => l.statusPlaced,
      OrderStatus.confirmed => l.statusConfirmed,
      OrderStatus.preparing => l.statusPreparing,
      OrderStatus.ready => l.statusReady,
      OrderStatus.outForDelivery => l.statusOutForDelivery,
      OrderStatus.delivered => l.statusDelivered,
      OrderStatus.rejected => l.statusRejected,
      OrderStatus.cancelled => l.statusCancelled,
    };

Color statusColor(FoodzPalette p, OrderStatus s) => switch (s) {
      OrderStatus.placed => p.warning,
      OrderStatus.confirmed || OrderStatus.preparing || OrderStatus.ready || OrderStatus.outForDelivery => p.primary,
      OrderStatus.delivered => p.success,
      OrderStatus.rejected || OrderStatus.cancelled => p.error,
    };

/// "16/11 14:32". Digits only, so it reads the same in all three languages.
String shortDateTime(DateTime? d) => d == null ? '' : DateFormat('dd/MM HH:mm').format(d.toLocal());
String shortTime(DateTime? d) => d == null ? '' : DateFormat('HH:mm').format(d.toLocal());

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = statusColor(context.palette, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s12, vertical: Space.s4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        statusLabel(context.l10n, status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// The dishes of an order: "2 × Chakhchoukha", extras underneath, optional prices.
class OrderLinesView extends StatelessWidget {
  const OrderLinesView({super.key, required this.lines, required this.lang, this.showPrices = true, this.large = false});

  final List<OrderLine> lines;
  final String lang;
  final bool showPrices;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = context.palette.textMuted;
    final main = large ? text.titleMedium : text.bodyLarge;
    return Column(
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${Fmt.number(line.qty, lang)} × ${line.name.of(lang)}',
                          style: main?.copyWith(fontWeight: FontWeight.w600)),
                      if (line.options.isNotEmpty)
                        Text(
                          line.options.map((o) => o.of(lang)).join(' · '),
                          style: text.bodySmall?.copyWith(color: muted),
                        ),
                    ],
                  ),
                ),
                if (showPrices) Text(Fmt.money(line.lineTotal, lang), style: text.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}

/// One row in a price summary.
class PriceRow extends StatelessWidget {
  const PriceRow(this.label, this.value, {super.key, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.textMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
