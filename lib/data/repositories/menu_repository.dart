import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/menu.dart';

/// Categories and dishes. Everyone can read; only admins and the owner can write
/// (enforced by firestore.rules).
class MenuRepository {
  MenuRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _categories => _db.collection('categories');
  CollectionReference<Map<String, dynamic>> get _dishes => _db.collection('dishes');

  Stream<List<MenuCategory>> watchCategories() => _categories.snapshots().map((s) {
        final list = s.docs.map(MenuCategory.fromDoc).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  Stream<List<Dish>> watchDishes() => _dishes.snapshots().map((s) {
        final list = s.docs.map(Dish.fromDoc).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  /// An empty id creates a new category.
  Future<void> saveCategory(MenuCategory c) {
    final ref = c.id.isEmpty ? _categories.doc() : _categories.doc(c.id);
    return ref.set(c.toMap());
  }

  Future<void> deleteCategory(String id) => _categories.doc(id).delete();

  String newDishId() => _dishes.doc().id;

  Future<void> saveDish(Dish d) => _dishes.doc(d.id).set(d.toMap());

  Future<void> setAvailable(String id, bool available) =>
      _dishes.doc(id).update({'available': available, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> deleteDish(String id) => _dishes.doc(id).delete();
}
