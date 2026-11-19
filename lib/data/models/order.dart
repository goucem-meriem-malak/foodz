import 'package:cloud_firestore/cloud_firestore.dart';

import 'localized.dart';

/// Order life cycle. The stored value is [wire]; the transitions that are
/// allowed are enforced by firestore.rules, not here.
enum OrderStatus {
  placed,
  confirmed,
  preparing,
  ready,
  outForDelivery,
  delivered,
  rejected,
  cancelled;

  String get wire => this == OrderStatus.outForDelivery ? 'out_for_delivery' : name;

  static OrderStatus parse(Object? v) {
    for (final s in OrderStatus.values) {
      if (s.wire == v) return s;
    }
    return OrderStatus.placed;
  }

  bool get isFinal =>
      this == OrderStatus.delivered || this == OrderStatus.rejected || this == OrderStatus.cancelled;
}

/// One line of an order. Names are copied into the order so later menu edits
/// never change an order that was already placed.
class OrderLine {
  const OrderLine({
    required this.dishId,
    required this.name,
    required this.options,
    required this.qty,
    required this.unitPrice,
  });

  final String dishId;
  final Localized name;
  final List<Localized> options;
  final int qty;

  /// Dish price plus chosen extras, for one portion.
  final int unitPrice;

  int get lineTotal => qty * unitPrice;

  factory OrderLine.fromMap(Map<dynamic, dynamic> m) => OrderLine(
        dishId: (m['dishId'] as String?) ?? '',
        name: Localized.fromMap(m['name']),
        options: ((m['options'] as List?) ?? const []).map(Localized.fromMap).toList(),
        qty: (m['qty'] as num?)?.toInt() ?? 1,
        unitPrice: (m['unitPrice'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toMap() => {
        'dishId': dishId,
        'name': name.toMap(),
        'options': options.map((o) => o.toMap()).toList(),
        'qty': qty,
        'unitPrice': unitPrice,
      };
}

class Order {
  const Order({
    required this.id,
    required this.clientUid,
    required this.code,
    required this.status,
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.area,
    required this.note,
    this.createdAt,
    this.confirmedAt,
    this.updatedAt,
    this.prepMinutes,
    this.readyAt,
    this.courierUid,
    this.rejectReason,
  });

  final String id;
  final String clientUid;
  final String code;
  final OrderStatus status;
  final List<OrderLine> lines;
  final int subtotal;
  final int deliveryFee;
  final int total;
  final String area;
  final String note;
  final DateTime? createdAt;
  final DateTime? confirmedAt;
  final DateTime? updatedAt;
  final int? prepMinutes;
  final DateTime? readyAt;
  final String? courierUid;
  final String? rejectReason;

  /// When the kitchen expects to be done (start of cooking plus preparation time).
  DateTime? get expectedReadyAt {
    if (status != OrderStatus.preparing || prepMinutes == null || updatedAt == null) return null;
    return updatedAt!.add(Duration(minutes: prepMinutes!));
  }

  factory Order.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const <String, dynamic>{};
    DateTime? ts(Object? v) => v is Timestamp ? v.toDate() : null;
    return Order(
      id: d.id,
      clientUid: (m['clientUid'] as String?) ?? '',
      code: (m['code'] as String?) ?? '',
      status: OrderStatus.parse(m['status']),
      lines: ((m['items'] as List?) ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(OrderLine.fromMap)
          .toList(),
      subtotal: (m['subtotal'] as num?)?.toInt() ?? 0,
      deliveryFee: (m['deliveryFee'] as num?)?.toInt() ?? 0,
      total: (m['total'] as num?)?.toInt() ?? 0,
      area: (m['area'] as String?) ?? '',
      note: (m['note'] as String?) ?? '',
      createdAt: ts(m['createdAt']),
      confirmedAt: ts(m['confirmedAt']),
      updatedAt: ts(m['updatedAt']),
      prepMinutes: (m['prepMinutes'] as num?)?.toInt(),
      readyAt: ts(m['readyAt']),
      courierUid: m['courierUid'] as String?,
      rejectReason: m['rejectReason'] as String?,
    );
  }
}

/// Name, phone and address of an order. Stored apart (orders/{id}/private/contact)
/// so the chef never sees it and a delivery person sees it only after taking the order.
class OrderContact {
  const OrderContact({required this.name, required this.phone, required this.address});

  final String name;
  final String phone;
  final String address;

  factory OrderContact.fromMap(Map<String, dynamic> m) => OrderContact(
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
      );
}
