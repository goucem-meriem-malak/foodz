import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/config/legal_version.dart';
import '../models/app_user.dart';

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('users').doc(uid);

  Stream<AppUser?> watchUser(String uid) =>
      _doc(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);

  /// Role, blocked flag and timestamps are fixed by the rules: a new profile
  /// can only be a non-blocked "client" that accepted the current terms.
  Future<void> createProfile({
    required String uid,
    required String name,
    required String phone,
    required String email,
    required String locale,
  }) {
    return _doc(uid).set({
      'name': name.trim(),
      'phone': phone,
      'email': email.trim().toLowerCase(),
      'role': 'client',
      'blocked': false,
      'locale': locale,
      'termsVersion': LegalVersions.current,
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile(String uid, {required String name, required String phone}) =>
      _doc(uid).update({'name': name.trim(), 'phone': phone});

  Future<void> updateLocale(String uid, String locale) => _doc(uid).update({'locale': locale});

  Future<void> acceptCurrentTerms(String uid) => _doc(uid).update({
        'termsVersion': LegalVersions.current,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
      });

  /// Removes the profile, the push tokens and the name, phone and address kept
  /// with each finished order. The orders themselves stay (the restaurant needs
  /// them for its accounts) but no longer point to a person's contact details.
  /// Refuses while an order is still open: a courier may need that address.
  Future<void> deleteAllData(String uid) async {
    final orders = await _db.collection('orders').where('clientUid', isEqualTo: uid).limit(400).get();
    const finished = {'delivered', 'cancelled', 'rejected'};
    if (orders.docs.any((o) => !finished.contains(o.data()['status']))) {
      throw const ActiveOrderException();
    }
    final devices = await _doc(uid).collection('devices').get();
    final batch = _db.batch();
    for (final o in orders.docs) {
      batch.delete(o.reference.collection('private').doc('contact'));
    }
    for (final d in devices.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_doc(uid));
    await batch.commit();
  }
}

/// Thrown when someone tries to delete their account while an order is in progress.
class ActiveOrderException implements Exception {
  const ActiveOrderException();
}
