import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.blocked,
    required this.locale,
    required this.termsVersion,
    this.termsAcceptedAt,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String phone;
  final String email;
  final UserRole role;
  final bool blocked;
  final String locale;
  final String termsVersion;
  final DateTime? termsAcceptedAt;
  final DateTime? createdAt;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) {
    DateTime? ts(Object? v) => v is Timestamp ? v.toDate() : null;
    return AppUser(
      uid: uid,
      name: (m['name'] as String?) ?? '',
      phone: (m['phone'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      role: UserRole.parse(m['role']),
      blocked: m['blocked'] == true,
      locale: (m['locale'] as String?) ?? 'fr',
      termsVersion: (m['termsVersion'] as String?) ?? '',
      termsAcceptedAt: ts(m['termsAcceptedAt']),
      createdAt: ts(m['createdAt']),
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      AppUser.fromMap(d.id, d.data() ?? const {});

  /// Everything stored about the user, for the "Export my data" screen.
  Map<String, Object?> toExport() => {
        'name': name,
        'phone': phone,
        'email': email,
        'role': role.name,
        'blocked': blocked,
        'language': locale,
        'termsVersionAccepted': termsVersion,
        'termsAcceptedAt': termsAcceptedAt?.toIso8601String(),
        'accountCreatedAt': createdAt?.toIso8601String(),
      };
}
