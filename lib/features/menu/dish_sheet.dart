import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../data/models/cart.dart';
import '../../data/models/menu.dart';
import '../../data/providers.dart';
import 'menu_screen.dart';

Future<void> showDishSheet(BuildContext context, Dish dish, {required bool canOrder}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.palette.bg,
    builder: (_) => DishSheet(dish: dish, canOrder: canOrder),
  );
}

/// Dish details with its options (size, extras), quantity and "add to cart".
class DishSheet extends ConsumerStatefulWidget {
  const DishSheet({super.key, required this.dish, required this.canOrder});
  final Dish dish;
  final bool canOrder;

  @override
  ConsumerState<DishSheet> createState() => _DishSheetState();
}

class _DishSheetState extends ConsumerState<DishSheet> {
  final Map<int, Set<int>> _picked = {};
  int _qty = 1;

  int get _extras {
    var sum = 0;
    for (final e in _picked.entries) {
      for (final i in e.value) {
        sum += widget.dish.options[e.key].choices[i].price;
      }
    }
    return sum;
  }

  String? _missingGroup(String lang) {
    for (var g = 0; g < widget.dish.options.length; g++) {
      final group = widget.dish.options[g];
      if (group.required && (_picked[g]?.isEmpty ?? true)) return group.name.of(lang);
    }
    return null;
  }

  void _add(String lang) {
    final l = context.l10n;
    final missing = _missingGroup(lang);
    if (missing != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.optionRequired(missing))));
      return;
    }
    final chosen = <OptionChoice>[];
    for (var g = 0; g < widget.dish.options.length; g++) {
      final idx = (_picked[g] ?? <int>{}).toList()..sort();
      for (final i in idx) {
        chosen.add(widget.dish.options[g].choices[i]);
      }
    }
    ref.read(cartProvider.notifier).add(widget.dish, chosen, _qty);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final dish = widget.dish;
    final enabled = dish.available && widget.canOrder;
    final total = (dish.price + _extras) * _qty;
    final desc = dish.description.of(lang);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.s24, 0, Space.s24, Space.s16),
            children: [
              Center(child: DishPhoto(url: dish.imageUrl, size: 180)),
              const SizedBox(height: Space.s16),
              Text(dish.name.of(lang), style: text.headlineSmall),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: Space.s8),
                Text(desc, style: text.bodyMedium?.copyWith(color: p.textMuted)),
              ],
              const SizedBox(height: Space.s8),
              Text(Fmt.money(dish.price, lang), style: text.titleMedium?.copyWith(color: p.primary)),
              for (var g = 0; g < dish.options.length; g++) ...[
                const SizedBox(height: Space.s24),
                Row(
                  children: [
                    Expanded(child: Text(dish.options[g].name.of(lang), style: text.titleMedium)),
                    Text(
                      dish.options[g].required
                          ? l.optionRequiredTag
                          : (dish.options[g].multi ? l.chooseAny : l.chooseOne),
                      style: text.labelMedium?.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
                for (var c = 0; c < dish.options[g].choices.length; c++)
                  _choiceTile(g, c, lang),
              ],
              const SizedBox(height: Space.s24),
              Row(
                children: [
                  Expanded(child: Text(l.quantity, style: text.titleMedium)),
                  IconButton.filledTonal(
                    tooltip: l.decrease,
                    onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(Fmt.number(_qty, lang), textAlign: TextAlign.center, style: text.titleMedium),
                  ),
                  IconButton.filledTonal(
                    tooltip: l.increase,
                    onPressed: _qty < maxQtyPerLine ? () => setState(() => _qty++) : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s24, Space.s8, Space.s24, Space.s16),
          child: AppButton(
            label: !dish.available
                ? l.soldOut
                : (!widget.canOrder ? l.closedShort : l.addForPrice(Fmt.money(total, lang))),
            onPressed: enabled ? () => _add(lang) : null,
          ),
        ),
      ],
    );
  }

  Widget _choiceTile(int g, int c, String lang) {
    final group = widget.dish.options[g];
    final choice = group.choices[c];
    final selected = _picked[g]?.contains(c) ?? false;
    final price = choice.price > 0 ? '+${Fmt.money(choice.price, lang)}' : null;
    void toggle(bool? on) => setState(() {
          final set = _picked.putIfAbsent(g, () => <int>{});
          if (group.multi) {
            on == true ? set.add(c) : set.remove(c);
          } else {
            set
              ..clear()
              ..add(c);
          }
        });
    final title = Text(choice.name.of(lang));
    final trailing = price == null ? null : Text(price);
    return group.multi
        ? CheckboxListTile(
            value: selected,
            onChanged: toggle,
            title: title,
            secondary: trailing,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          )
        : RadioListTile<int>(
            value: c,
            groupValue: (_picked[g]?.isEmpty ?? true) ? null : _picked[g]!.first,
            onChanged: (_) => toggle(true),
            title: title,
            secondary: trailing,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          );
  }
}
