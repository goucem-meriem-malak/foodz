import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';

/// Staff and customer list for admins and the owner. Reading everyone is allowed
/// only to admins; changing a role only to the owner; blocking a customer to both.
class TeamRepository {
  TeamRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<AppUser>> watchUsers() => _db.collection('users').limit(300).snapshots().map((s) {
        final list = s.docs.map(AppUser.fromDoc).toList();
        list.sort((a, b) {
          final byRole = a.role.index.compareTo(b.role.index);
          return byRole != 0 ? byRole : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return list;
      });

  Future<void> setRole(String uid, UserRole role) => _db.collection('users').doc(uid).update({'role': role.name});

  Future<void> setBlocked(String uid, bool blocked) =>
      _db.collection('users').doc(uid).update({'blocked': blocked});
}
