import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodz/data/models/app_settings.dart';
import 'package:foodz/data/models/app_user.dart';
import 'package:foodz/data/models/user_role.dart';

void main() {
  group('UserRole', () {
    test('unknown or missing values become the least privileged role', () {
      expect(UserRole.parse('superadmin'), UserRole.client);
      expect(UserRole.parse(null), UserRole.client);
      expect(UserRole.parse('chef'), UserRole.chef);
    });
    test('permissions follow the permission matrix', () {
      expect(UserRole.owner.canManageStaff, isTrue);
      expect(UserRole.admin.canManageStaff, isFalse);
      expect(UserRole.admin.canManageMenu, isTrue);
      expect(UserRole.chef.canManageMenu, isFalse);
      expect(UserRole.client.isStaff, isFalse);
      expect(UserRole.delivery.isStaff, isTrue);
    });
  });

  group('AppUser', () {
    test('reads a Firestore document and exports readable data', () {
      final user = AppUser.fromMap('u1', {
        'name': 'Samira Haddad',
        'phone': '0661234567',
        'email': 'samira@example.dz',
        'role': 'admin',
        'blocked': false,
        'locale': 'ar',
        'termsVersion': '1.0',
        'termsAcceptedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 16)),
      });
      expect(user.role, UserRole.admin);
      expect(user.termsAcceptedAt!.toUtc(), DateTime.utc(2026, 11, 16));
      expect(user.toExport()['termsAcceptedAt'], isA<String>());
      expect(user.toExport().containsKey('uid'), isFalse);
    });
    test('missing fields never crash and default to safe values', () {
      final user = AppUser.fromMap('u2', const {});
      expect(user.role, UserRole.client);
      expect(user.blocked, isFalse);
      expect(user.termsVersion, '');
    });
  });

  group('AppSettings', () {
    test('uses defaults until the owner saves settings', () {
      final s = AppSettings.fromMap(null);
      expect(s.acceptingOrders, isTrue);
      expect(s.hasContact, isFalse);
    });
    test('reads stored values', () {
      final s = AppSettings.fromMap({
        'restaurantName': 'Dar Ennakhla',
        'deliveryFee': 300,
        'minOrder': 1000,
        'defaultPrepMinutes': 25,
        'acceptingOrders': false,
        'contactPhone': '0550000000',
        'contactEmail': '',
      });
      expect(s.deliveryFee, 300);
      expect(s.acceptingOrders, isFalse);
      expect(s.hasContact, isTrue);
    });
  });
}
