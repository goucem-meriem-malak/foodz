import 'package:intl/intl.dart';

/// Number formatting per language. Algerians read Western digits (0-9) even in
/// Arabic, so the Arabic locale uses the Algerian number symbols.
abstract final class Fmt {
  static String _numberTag(String languageCode) => languageCode == 'ar' ? 'ar_DZ' : languageCode;

  static String number(num value, String languageCode) {
    try {
      return NumberFormat.decimalPattern(_numberTag(languageCode)).format(value);
    } catch (_) {
      // Unknown locale data: fall back to French grouping.
      return NumberFormat.decimalPattern('fr').format(value);
    }
  }

  /// Prices are whole dinars: "1,200 DA" or "1 200 DA", "1,200 د.ج" in Arabic.
  static String money(int dinars, String languageCode) {
    final symbol = languageCode == 'ar' ? 'د.ج' : 'DA';
    return '${number(dinars, languageCode)} $symbol';
  }
}
