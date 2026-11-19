import 'package:flutter_test/flutter_test.dart';
import 'package:foodz/data/models/localized.dart';
import 'package:foodz/data/models/order.dart';
import 'package:foodz/data/models/sales_stats.dart';

Order _order(String id, int total, List<OrderLine> lines) => Order(
      id: id,
      clientUid: 'c',
      code: 'A7K2',
      status: OrderStatus.delivered,
      lines: lines,
      subtotal: total - 200,
      deliveryFee: 200,
      total: total,
      area: 'x',
      note: '',
    );

OrderLine _line(String id, String name, int qty) =>
    OrderLine(dishId: id, name: Localized.all(name), options: const [], qty: qty, unitPrice: 900);

void main() {
  test('adds up orders, revenue and average', () {
    final s = SalesStats.from([
      _order('1', 2000, [_line('a', 'Couscous', 2)]),
      _order('2', 1000, [_line('b', 'Rechta', 1)]),
    ]);
    expect(s.orders, 2);
    expect(s.revenue, 3000);
    expect(s.average, 1500);
  });

  test('ranks best sellers by quantity', () {
    final s = SalesStats.from([
      _order('1', 2000, [_line('a', 'Couscous', 1), _line('b', 'Rechta', 3)]),
      _order('2', 1000, [_line('a', 'Couscous', 1)]),
    ]);
    expect(s.top.first.name.en, 'Rechta');
    expect(s.top.first.qty, 3);
    expect(s.top[1].qty, 2);
  });

  test('empty list gives zeros', () {
    final s = SalesStats.from(const []);
    expect(s.orders, 0);
    expect(s.average, 0);
    expect(s.top, isEmpty);
  });
}
