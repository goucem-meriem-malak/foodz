import 'localized.dart';
import 'order.dart';

class TopDish {
  const TopDish(this.name, this.qty);
  final Localized name;
  final int qty;
}

/// Totals over delivered orders: how many, how much, and the best sellers.
class SalesStats {
  const SalesStats({required this.orders, required this.revenue, required this.top});

  final int orders;
  final int revenue;
  final List<TopDish> top;

  int get average => orders == 0 ? 0 : (revenue / orders).round();

  factory SalesStats.from(Iterable<Order> delivered, {int topCount = 5}) {
    var count = 0;
    var revenue = 0;
    final qty = <String, int>{};
    final names = <String, Localized>{};
    for (final o in delivered) {
      count++;
      revenue += o.total;
      for (final line in o.lines) {
        qty[line.dishId] = (qty[line.dishId] ?? 0) + line.qty;
        names.putIfAbsent(line.dishId, () => line.name);
      }
    }
    final ranked = qty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return SalesStats(
      orders: count,
      revenue: revenue,
      top: [for (final e in ranked.take(topCount)) TopDish(names[e.key]!, e.value)],
    );
  }
}
