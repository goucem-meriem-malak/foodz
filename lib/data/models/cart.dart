import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'localized.dart';
import 'menu.dart';

class CartLine {
  const CartLine({required this.key, required this.dish, required this.chosen, required this.qty});

  final String key;
  final Dish dish;
  final List<OptionChoice> chosen;
  final int qty;

  int get unitPrice => dish.price + chosen.fold<int>(0, (s, c) => s + c.price);
  int get total => unitPrice * qty;

  CartLine withQty(int q) => CartLine(key: key, dish: dish, chosen: chosen, qty: q);

  Map<String, Object?> toOrderMap() => {
        'dishId': dish.id,
        'name': dish.name.toMap(),
        'options': chosen.map((c) => c.name.toMap()).toList(),
        'qty': qty,
        'unitPrice': unitPrice,
      };

  Localized get name => dish.name;
}

const maxQtyPerLine = 20;
const maxCartLines = 40;

/// The cart lives in memory only: it is cleared when the app closes, and it
/// survives signing in because it is not tied to a user.
class CartNotifier extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  void add(Dish dish, List<OptionChoice> chosen, int qty) {
    final key = '${dish.id}|${chosen.map((c) => c.name.en + c.name.fr + c.name.ar).join(',')}';
    final i = state.indexWhere((l) => l.key == key);
    if (i >= 0) {
      final next = [...state];
      next[i] = next[i].withQty((next[i].qty + qty).clamp(1, maxQtyPerLine));
      state = next;
    } else if (state.length < maxCartLines) {
      state = [...state, CartLine(key: key, dish: dish, chosen: chosen, qty: qty.clamp(1, maxQtyPerLine))];
    }
  }

  void setQty(String key, int qty) {
    if (qty <= 0) {
      state = state.where((l) => l.key != key).toList();
    } else {
      state = [
        for (final l in state) l.key == key ? l.withQty(qty.clamp(1, maxQtyPerLine)) : l,
      ];
    }
  }

  void clear() => state = const [];
}

final cartProvider = NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);

int cartSubtotal(List<CartLine> lines) => lines.fold<int>(0, (s, l) => s + l.total);
int cartCount(List<CartLine> lines) => lines.fold<int>(0, (s, l) => s + l.qty);
