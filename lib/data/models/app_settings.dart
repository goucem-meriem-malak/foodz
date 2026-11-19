/// Opening hours of one weekday, in minutes after midnight (open 660 = 11:00).
/// A close time at or before the open time means the shop closes after midnight.
class DayHours {
  const DayHours({this.closed = false, this.open = 660, this.close = 1380});

  final bool closed;
  final int open;
  final int close;

  DayHours copyWith({bool? closed, int? open, int? close}) =>
      DayHours(closed: closed ?? this.closed, open: open ?? this.open, close: close ?? this.close);

  factory DayHours.fromMap(Object? m) {
    if (m is! Map) return const DayHours();
    int n(String k, int fallback) => (m[k] is num) ? (m[k] as num).toInt() : fallback;
    return DayHours(closed: m['closed'] == true, open: n('open', 660).clamp(0, 1439), close: n('close', 1380).clamp(0, 1440));
  }

  Map<String, Object> toMap() => {'closed': closed, 'open': open, 'close': close};

  bool get overnight => close <= open;
}

/// Restaurant-wide settings, stored in settings/app (public read, owner write).
class AppSettings {
  const AppSettings({
    required this.restaurantName,
    required this.deliveryFee,
    required this.minOrder,
    required this.defaultPrepMinutes,
    required this.acceptingOrders,
    required this.contactPhone,
    required this.contactEmail,
    this.hours = const {},
  });

  final String restaurantName;
  final int deliveryFee;
  final int minOrder;
  final int defaultPrepMinutes;

  /// Manual switch: the owner can stop new orders at any time.
  final bool acceptingOrders;
  final String contactPhone;
  final String contactEmail;

  /// Weekly opening hours, keyed by weekday (1 = Monday ... 7 = Sunday).
  /// Empty means no schedule: the shop is open whenever [acceptingOrders] is on.
  final Map<int, DayHours> hours;

  /// Used until the owner saves the settings for the first time.
  static const AppSettings defaults = AppSettings(
    restaurantName: 'Foodz',
    deliveryFee: 0,
    minOrder: 0,
    defaultPrepMinutes: 20,
    acceptingOrders: true,
    contactPhone: '',
    contactEmail: '',
  );

  /// A starting schedule for the settings form: every day 11:00 to 23:00.
  static Map<int, DayHours> get defaultWeek => {for (var d = 1; d <= 7; d++) d: const DayHours()};

  factory AppSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    int n(String k, int fallback) => (m[k] is num) ? (m[k] as num).toInt() : fallback;
    final rawHours = m['hours'];
    final hours = <int, DayHours>{};
    if (rawHours is Map) {
      rawHours.forEach((k, v) {
        final day = int.tryParse('$k');
        if (day != null && day >= 1 && day <= 7) hours[day] = DayHours.fromMap(v);
      });
    }
    return AppSettings(
      restaurantName: (m['restaurantName'] as String?)?.trim().isNotEmpty == true
          ? m['restaurantName'] as String
          : defaults.restaurantName,
      deliveryFee: n('deliveryFee', defaults.deliveryFee),
      minOrder: n('minOrder', defaults.minOrder),
      defaultPrepMinutes: n('defaultPrepMinutes', defaults.defaultPrepMinutes),
      acceptingOrders: m['acceptingOrders'] != false,
      contactPhone: (m['contactPhone'] as String?) ?? '',
      contactEmail: (m['contactEmail'] as String?) ?? '',
      hours: hours,
    );
  }

  bool get hasContact => contactPhone.isNotEmpty || contactEmail.isNotEmpty;

  /// True when new orders can be placed right now: the switch is on and, if a
  /// schedule exists, the shop is inside today's hours (device clock).
  bool openNow([DateTime? at]) {
    if (!acceptingOrders) return false;
    if (hours.isEmpty) return true;
    final now = at ?? DateTime.now();
    final minute = now.hour * 60 + now.minute;
    final today = hours[now.weekday];
    if (today != null && !today.closed) {
      if (today.overnight ? minute >= today.open : (minute >= today.open && minute < today.close)) return true;
    }
    final yesterday = hours[now.weekday == 1 ? 7 : now.weekday - 1];
    if (yesterday != null && !yesterday.closed && yesterday.overnight && minute < yesterday.close) return true;
    return false;
  }

  Map<String, Object> hoursToMap() => {for (final e in hours.entries) '${e.key}': e.value.toMap()};
}
