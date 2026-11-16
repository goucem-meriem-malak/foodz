import '../l10n/l10n.dart';

enum FieldError { required, name, email, password, phone }

/// Client-side validation is only for fast feedback. The same rules are
/// enforced again in firestore.rules, which is what actually protects data.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final RegExp _phone = RegExp(r'^0([567]\d{8}|[234]\d{7})$');
  static final RegExp _letter = RegExp(r'[A-Za-z؀-ۿ]');
  static final RegExp _digit = RegExp(r'\d');

  /// "+213 555 12 34 56" and "00213555123456" become "0555123456".
  static String normalizePhone(String raw) {
    var s = raw.replaceAll(RegExp(r'[\s\-.()]'), '');
    if (s.startsWith('+213')) {
      s = '0${s.substring(4)}';
    } else if (s.startsWith('00213')) {
      s = '0${s.substring(5)}';
    }
    return s;
  }

  static FieldError? required(String? v) =>
      (v == null || v.trim().isEmpty) ? FieldError.required : null;

  static FieldError? name(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return FieldError.required;
    if (s.length < 2 || s.length > 60) return FieldError.name;
    return null;
  }

  static FieldError? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return FieldError.required;
    if (s.length > 100 || !_email.hasMatch(s)) return FieldError.email;
    return null;
  }

  static FieldError? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return FieldError.required;
    if (s.length < 8 || s.length > 128 || !_letter.hasMatch(s) || !_digit.hasMatch(s)) {
      return FieldError.password;
    }
    return null;
  }

  static FieldError? phone(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return FieldError.required;
    return _phone.hasMatch(normalizePhone(s)) ? null : FieldError.phone;
  }
}

extension FieldErrorText on FieldError {
  String text(AppLocalizations l) => switch (this) {
        FieldError.required => l.errRequired,
        FieldError.name => l.errName,
        FieldError.email => l.errEmail,
        FieldError.password => l.errPassword,
        FieldError.phone => l.errPhone,
      };
}
