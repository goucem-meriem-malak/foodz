import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('settings').doc('app');

  Stream<AppSettings> watch() => _doc.snapshots().map((d) => AppSettings.fromMap(d.data()));

  /// Owner only (rules). Writes exactly the fields the rules expect.
  Future<void> save(AppSettings s) => _doc.set({
        'restaurantName': s.restaurantName.trim(),
        'deliveryFee': s.deliveryFee,
        'minOrder': s.minOrder,
        'defaultPrepMinutes': s.defaultPrepMinutes,
        'acceptingOrders': s.acceptingOrders,
        'contactPhone': s.contactPhone.trim(),
        'contactEmail': s.contactEmail.trim(),
        if (s.hours.isNotEmpty) 'hours': s.hoursToMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
