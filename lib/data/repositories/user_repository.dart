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

  /// Removes the profile and the push tokens. Orders keep no contact details
  /// (those are deleted with the account in the orders feature).
  Future<void> deleteAllData(String uid) async {
    final devices = await _doc(uid).collection('devices').get();
    final batch = _db.batch();
    for (final d in devices.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_doc(uid));
    await batch.commit();
  }
}
