import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._db);
  final FirebaseFirestore _db;

  Stream<AppSettings> watch() => _db
      .collection('settings')
      .doc('app')
      .snapshots()
      .map((d) => AppSettings.fromMap(d.data()));
}
