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
  });

  final String restaurantName;
  final int deliveryFee;
  final int minOrder;
  final int defaultPrepMinutes;
  final bool acceptingOrders;
  final String contactPhone;
  final String contactEmail;

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

  factory AppSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    int n(String k, int fallback) => (m[k] is num) ? (m[k] as num).toInt() : fallback;
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
    );
  }

  bool get hasContact => contactPhone.isNotEmpty || contactEmail.isNotEmpty;
}
