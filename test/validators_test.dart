import 'package:flutter_test/flutter_test.dart';
import 'package:foodz/core/security/validators.dart';

void main() {
  group('phone', () {
    test('accepts Algerian mobile numbers in common writings', () {
      for (final ok in ['0555123456', '0661 23 45 67', '+213 770 12 34 56', '00213555123456', '023123456']) {
        expect(Validators.phone(ok), isNull, reason: ok);
      }
    });
    test('rejects wrong numbers', () {
      for (final bad in ['', '0155123456', '055512345', '05551234567', 'abcdefghij', '+33612345678']) {
        expect(Validators.phone(bad), isNotNull, reason: bad);
      }
    });
    test('normalizes to the local format stored in the database', () {
      expect(Validators.normalizePhone('+213 555 12 34 56'), '0555123456');
      expect(Validators.normalizePhone('0555-12-34-56'), '0555123456');
    });
  });

  group('email', () {
    test('valid and invalid', () {
      expect(Validators.email('amine@example.dz'), isNull);
      expect(Validators.email('amine@'), FieldError.email);
      expect(Validators.email('  '), FieldError.required);
    });
  });

  group('password', () {
    test('needs 8+ characters with a letter and a digit', () {
      expect(Validators.password('abc12345'), isNull);
      expect(Validators.password('كلمةسر123'), isNull);
      expect(Validators.password('abcdefgh'), FieldError.password);
      expect(Validators.password('12345678'), FieldError.password);
      expect(Validators.password('a1'), FieldError.password);
      expect(Validators.password(''), FieldError.required);
    });
  });

  group('name', () {
    test('2 to 60 characters', () {
      expect(Validators.name('Lina Boudiaf'), isNull);
      expect(Validators.name('A'), FieldError.name);
      expect(Validators.name('x' * 61), FieldError.name);
    });
  });
}
