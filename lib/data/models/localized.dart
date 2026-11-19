/// Text in the three app languages. Falls back to another language when the
/// wanted one is empty, so a dish never shows a blank name.
class Localized {
  const Localized({this.ar = '', this.fr = '', this.en = ''});
  const Localized.all(String v)
      : ar = v,
        fr = v,
        en = v;

  final String ar;
  final String fr;
  final String en;

  factory Localized.fromMap(Object? m) {
    if (m is Map) {
      String s(String k) => (m[k] as String?) ?? '';
      return Localized(ar: s('ar'), fr: s('fr'), en: s('en'));
    }
    return const Localized();
  }

  Map<String, String> toMap() => {'ar': ar, 'fr': fr, 'en': en};

  String of(String lang) {
    final first = switch (lang) {
      'ar' => ar,
      'fr' => fr,
      _ => en,
    };
    if (first.trim().isNotEmpty) return first;
    for (final v in [fr, en, ar]) {
      if (v.trim().isNotEmpty) return v;
    }
    return '';
  }

  bool get isEmpty => ar.trim().isEmpty && fr.trim().isEmpty && en.trim().isEmpty;
}
