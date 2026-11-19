import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../../core/services/notify_service.dart';
import '../models/cart.dart';
import '../models/order.dart';

/// All order reads and writes. Every status change is checked again by
/// firestore.rules, so a hacked app still cannot skip a step or change someone
/// else's order. After each change the push server is asked to alert people.
class OrdersRepository {
  OrdersRepository(this._db, this._notify);
  final FirebaseFirestore _db;
  final NotifyService _notify;

  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');
  DocumentReference<Map<String, dynamic>> _lock(String uid) => _db.collection('placedLocks').doc(uid);

  static List<Order> _list(QuerySnapshot<Map<String, dynamic>> s) => s.docs.map(Order.fromDoc).toList();

  static int _byDate(Order a, Order b) =>
      (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now());

  // ---------- reads ----------
  Stream<List<Order>> watchMine(String uid) => _orders
      .where('clientUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map(_list);

  Stream<Order?> watchOrder(String id) =>
      _orders.doc(id).snapshots().map((d) => d.exists ? Order.fromDoc(d) : null);

  /// Oldest first, for boards where the longest waiting order comes first.
  Stream<List<Order>> watchStatuses(List<OrderStatus> statuses) => _orders
      .where('status', whereIn: statuses.map((s) => s.wire).toList())
      .snapshots()
      .map((s) => _list(s)..sort(_byDate));

  Stream<List<Order>> watchHistory() => _orders
      .where('status', whereIn: ['delivered', 'rejected', 'cancelled'])
      .orderBy('createdAt', descending: true)
      .limit(40)
      .snapshots()
      .map(_list);

  Stream<List<Order>> watchCourierOrders(String uid) => _orders
      .where('courierUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map(_list);

  /// Delivered orders since [since], newest first (at most 500), for the owner's sales numbers.
  Future<List<Order>> deliveredSince(DateTime since) async {
    final s = await _orders
        .where('status', isEqualTo: 'delivered')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();
    return _list(s);
  }

  /// Null when the caller is not allowed to see it (for example a delivery
  /// person before taking the order).
  Future<OrderContact?> contactOf(String orderId) async {
    try {
      final d = await _orders.doc(orderId).collection('private').doc('contact').get();
      final data = d.data();
      return data == null ? null : OrderContact.fromMap(data);
    } on FirebaseException {
      return null;
    }
  }

  // ---------- customer ----------
  static String _code() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Creates the order, its private contact details and the "one unconfirmed
  /// order" lock in one batch: all three are written or none.
  Future<String> place({
    required String uid,
    required List<CartLine> lines,
    required int deliveryFee,
    required String name,
    required String phone,
    required String area,
    required String address,
    required String note,
  }) async {
    final subtotal = cartSubtotal(lines);
    final ref = _orders.doc();
    final batch = _db.batch();
    batch.set(ref, {
      'clientUid': uid,
      'code': _code(),
      'status': 'placed',
      'items': lines.map((l) => l.toOrderMap()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': subtotal + deliveryFee,
      'area': area.trim(),
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'confirmedAt': null,
      'confirmedBy': null,
      'prepMinutes': null,
      'readyAt': null,
      'courierUid': null,
      'rejectReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref.collection('private').doc('contact'), {
      'name': name.trim(),
      'phone': phone,
      'address': address.trim(),
    });
    batch.set(_lock(uid), {'orderId': ref.id});
    await batch.commit();
    unawaited(_notify.orderChanged(ref.id));
    return ref.id;
  }

  Future<void> cancelByClient(Order o) => _leavePlaced(o, {'status': 'cancelled'});

  // ---------- admin ----------
  Future<void> confirm(Order o, String adminUid) => _leavePlaced(o, {
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
        'confirmedBy': adminUid,
      });

  Future<void> reject(Order o, String reason) =>
      _leavePlaced(o, {'status': 'rejected', 'rejectReason': reason.trim()});

  /// Moves an order out of "placed" and frees the customer's lock in one batch.
  Future<void> _leavePlaced(Order o, Map<String, Object?> fields) async {
    final batch = _db.batch();
    batch.update(_orders.doc(o.id), {...fields, 'updatedAt': FieldValue.serverTimestamp()});
    batch.delete(_lock(o.clientUid));
    await batch.commit();
    unawaited(_notify.orderChanged(o.id));
  }

  Future<void> adminCancel(String id) => _update(id, {'status': 'cancelled'});

  Future<void> assignCourier(String id, String courierUid) =>
      _update(id, {'status': 'out_for_delivery', 'courierUid': courierUid});

  // ---------- chef ----------
  Future<void> startCooking(String id, int minutes) =>
      _update(id, {'status': 'preparing', 'prepMinutes': minutes});

  Future<void> markReady(String id) =>
      _update(id, {'status': 'ready', 'readyAt': FieldValue.serverTimestamp()});

  // ---------- delivery ----------
  Future<void> takeDelivery(String id, String courierUid) =>
      _update(id, {'status': 'out_for_delivery', 'courierUid': courierUid});

  Future<void> markDelivered(String id) => _update(id, {'status': 'delivered'});

  Future<void> _update(String id, Map<String, Object?> fields) async {
    await _orders.doc(id).update({...fields, 'updatedAt': FieldValue.serverTimestamp()});
    unawaited(_notify.orderChanged(id));
  }
}
