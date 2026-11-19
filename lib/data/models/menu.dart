import 'package:cloud_firestore/cloud_firestore.dart';

import 'localized.dart';

class MenuCategory {
  const MenuCategory({required this.id, required this.name, required this.order, required this.active});

  final String id;
  final Localized name;
  final int order;
  final bool active;

  factory MenuCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const <String, dynamic>{};
    return MenuCategory(
      id: d.id,
      name: Localized.fromMap(m['name']),
      order: (m['order'] as num?)?.toInt() ?? 0,
      active: m['active'] != false,
    );
  }

  Map<String, Object?> toMap() => {'name': name.toMap(), 'order': order, 'active': active};
}

/// One choice inside an option group, for example "Large +200 DA".
class OptionChoice {
  const OptionChoice({required this.name, required this.price});

  final Localized name;
  final int price;

  factory OptionChoice.fromMap(Map<dynamic, dynamic> m) =>
      OptionChoice(name: Localized.fromMap(m['name']), price: (m['price'] as num?)?.toInt() ?? 0);

  Map<String, Object?> toMap() => {'name': name.toMap(), 'price': price};
}

/// A group of choices on a dish: "Size" (pick one) or "Extras" (pick any).
class OptionGroup {
  const OptionGroup({
    required this.name,
    required this.required,
    required this.multi,
    required this.choices,
  });

  final Localized name;
  final bool required;
  final bool multi;
  final List<OptionChoice> choices;

  factory OptionGroup.fromMap(Map<dynamic, dynamic> m) => OptionGroup(
        name: Localized.fromMap(m['name']),
        required: m['required'] == true,
        multi: m['multi'] == true,
        choices: ((m['choices'] as List?) ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map(OptionChoice.fromMap)
            .toList(),
      );

  Map<String, Object?> toMap() => {
        'name': name.toMap(),
        'required': required,
        'multi': multi,
        'choices': choices.map((c) => c.toMap()).toList(),
      };
}

class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.imageUrl,
    required this.available,
    required this.options,
    required this.order,
  });

  final String id;
  final Localized name;
  final Localized description;
  final int price;
  final String categoryId;
  final String imageUrl;
  final bool available;
  final List<OptionGroup> options;
  final int order;

  factory Dish.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const <String, dynamic>{};
    return Dish(
      id: d.id,
      name: Localized.fromMap(m['name']),
      description: Localized.fromMap(m['description']),
      price: (m['price'] as num?)?.toInt() ?? 0,
      categoryId: (m['categoryId'] as String?) ?? '',
      imageUrl: (m['imageUrl'] as String?) ?? '',
      available: m['available'] != false,
      options: ((m['options'] as List?) ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(OptionGroup.fromMap)
          .toList(),
      order: (m['order'] as num?)?.toInt() ?? 0,
    );
  }

  /// Exactly the fields the Firestore rules accept for a dish.
  Map<String, Object?> toMap() => {
        'name': name.toMap(),
        'description': description.toMap(),
        'price': price,
        'categoryId': categoryId,
        if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'available': available,
        'options': options.map((o) => o.toMap()).toList(),
        'order': order,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
