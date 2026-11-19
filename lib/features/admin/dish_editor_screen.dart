import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/language_menu.dart';
import '../../core/widgets/page_list.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/models/localized.dart';
import '../../data/models/menu.dart';
import '../../data/providers.dart';

/// Create or edit one dish. The id "new" creates a dish.
class DishEditorScreen extends ConsumerWidget {
  const DishEditorScreen({super.key, required this.dishId});
  final String dishId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dishes = ref.watch(dishesProvider);
    final isNew = dishId == 'new';
    final existing = dishes.valueOrNull?.where((d) => d.id == dishId).toList() ?? const <Dish>[];

    Widget body;
    if (dishes.isLoading) {
      body = const Padding(padding: EdgeInsets.all(Space.s24), child: ListSkeleton());
    } else if (!isNew && existing.isEmpty) {
      body = StateView(icon: Icons.search_off_rounded, title: l.dishNotFound);
    } else {
      body = _DishForm(dish: isNew ? null : existing.first);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l.addDish : l.editDish),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
      ),
      body: body,
    );
  }
}

class _ChoiceDraft {
  _ChoiceDraft(String name, int price)
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price == 0 ? '' : '$price');
  final TextEditingController name;
  final TextEditingController price;
  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _GroupDraft {
  _GroupDraft(String name, this.required, this.multi, this.choices) : name = TextEditingController(text: name);
  final TextEditingController name;
  bool required;
  bool multi;
  final List<_ChoiceDraft> choices;
  void dispose() {
    name.dispose();
    for (final c in choices) {
      c.dispose();
    }
  }
}

class _DishForm extends ConsumerStatefulWidget {
  const _DishForm({required this.dish});
  final Dish? dish;

  @override
  ConsumerState<_DishForm> createState() => _DishFormState();
}

class _DishFormState extends ConsumerState<_DishForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _names;
  late final Map<String, TextEditingController> _descs;
  late final _price = TextEditingController(text: widget.dish == null ? '' : '${widget.dish!.price}');
  late final _image = TextEditingController(text: widget.dish?.imageUrl ?? '');
  late String _categoryId = widget.dish?.categoryId ?? '';
  late bool _available = widget.dish?.available ?? true;
  late final List<_GroupDraft> _groups;
  bool _busy = false;
  bool _uploading = false;
  String? _error;

  static String _pick(Localized v, String code) => switch (code) {
        'ar' => v.ar,
        'fr' => v.fr,
        _ => v.en,
      };

  @override
  void initState() {
    super.initState();
    final d = widget.dish;
    _names = {for (final c in languageNames.keys) c: TextEditingController(text: d == null ? '' : _pick(d.name, c))};
    _descs = {for (final c in languageNames.keys) c: TextEditingController(text: d == null ? '' : _pick(d.description, c))};
    final lang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _groups = [
      for (final g in d?.options ?? const <OptionGroup>[])
        _GroupDraft(
          g.name.of(lang),
          g.required,
          g.multi,
          [for (final c in g.choices) _ChoiceDraft(c.name.of(lang), c.price)],
        ),
    ];
  }

  @override
  void dispose() {
    for (final c in [..._names.values, ..._descs.values, _price, _image]) {
      c.dispose();
    }
    for (final g in _groups) {
      g.dispose();
    }
    super.dispose();
  }

  String? _optionalLen(String? v, int max) {
    return (v ?? '').trim().length > max ? context.l10n.errTooShortOrLong : null;
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;

    final name = Localized(
      ar: _names['ar']!.text.trim(),
      fr: _names['fr']!.text.trim(),
      en: _names['en']!.text.trim(),
    );
    if (name.isEmpty) {
      setState(() => _error = l.dishNameRequired);
      return;
    }
    if (_categoryId.isEmpty) {
      setState(() => _error = l.categoryRequired);
      return;
    }
    final groups = <OptionGroup>[];
    for (final g in _groups) {
      final gName = g.name.text.trim();
      final choices = <OptionChoice>[];
      for (final c in g.choices) {
        final cName = c.name.text.trim();
        final price = int.tryParse(c.price.text.trim().isEmpty ? '0' : c.price.text.trim());
        if (cName.isEmpty || cName.length > 80 || price == null || price < 0 || price > 100000) {
          setState(() => _error = l.optionsInvalid);
          return;
        }
        choices.add(OptionChoice(name: Localized.all(cName), price: price));
      }
      if (gName.isEmpty || gName.length > 80 || choices.isEmpty) {
        setState(() => _error = l.optionsInvalid);
        return;
      }
      groups.add(OptionGroup(name: Localized.all(gName), required: g.required, multi: g.multi, choices: choices));
    }

    final repo = ref.read(menuRepositoryProvider);
    final existing = ref.read(dishesProvider).valueOrNull ?? const <Dish>[];
    final nextOrder = existing.fold<int>(0, (m, d) => d.order > m ? d.order : m) + 1;
    final dish = Dish(
      id: widget.dish?.id ?? repo.newDishId(),
      name: name,
      description: Localized(
        ar: _descs['ar']!.text.trim(),
        fr: _descs['fr']!.text.trim(),
        en: _descs['en']!.text.trim(),
      ),
      price: int.parse(_price.text.trim()),
      categoryId: _categoryId,
      imageUrl: _image.text.trim(),
      available: _available,
      options: groups,
      order: widget.dish?.order ?? nextOrder,
    );

    setState(() => _busy = true);
    try {
      await repo.saveDish(dish);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.savedMessage)));
      context.canPop() ? context.pop() : context.go('/home');
    } catch (_) {
      if (mounted) setState(() => _error = l.errSave);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteDishTitle),
        content: Text(l.deleteDishBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(menuRepositoryProvider).deleteDish(widget.dish!.id);
      if (mounted) context.canPop() ? context.pop() : context.go('/home');
    } catch (_) {
      if (mounted) setState(() => _error = l.errGeneric);
    }
  }

  Future<void> _pickPhoto() async {
    final l = context.l10n;
    final uploader = ref.read(imageUploadServiceProvider);
    if (!uploader.isConfigured) {
      setState(() => _error = l.photoNotConfigured);
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (picked == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await uploader.upload(await picked.readAsBytes());
      if (mounted) setState(() => _image.text = url);
    } catch (_) {
      if (mounted) setState(() => _error = l.photoFailed);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _photoPicker() {
    final l = context.l10n;
    final p = context.palette;
    return ListenableBuilder(
      listenable: _image,
      builder: (context, _) {
        final url = _image.text.trim();
        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.lg),
              child: SizedBox(
                width: 72,
                height: 72,
                child: url.startsWith('https://')
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            ColoredBox(color: p.surfaceTonal, child: const Icon(Icons.broken_image_outlined)),
                      )
                    : ColoredBox(color: p.surfaceTonal, child: const Icon(Icons.image_outlined)),
              ),
            ),
            const SizedBox(width: Space.s16),
            Expanded(
              child: AppButton(
                label: url.isEmpty ? l.choosePhoto : l.changePhoto,
                icon: Icons.photo_library_outlined,
                kind: AppButtonKind.secondary,
                loading: _uploading,
                onPressed: (_busy || _uploading) ? null : _pickPhoto,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const <MenuCategory>[];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Space.s24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Layout.formWidth * 1.3),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in languageNames.entries) ...[
                      AppTextField(
                        controller: _names[e.key]!,
                        label: l.fieldName(e.value),
                        validator: (v) => _optionalLen(v, 80),
                      ),
                      const SizedBox(height: Space.s12),
                    ],
                    for (final e in languageNames.entries) ...[
                      AppTextField(
                        controller: _descs[e.key]!,
                        label: l.fieldDescription(e.value),
                        validator: (v) => _optionalLen(v, 400),
                      ),
                      const SizedBox(height: Space.s12),
                    ],
                    AppTextField(
                      controller: _price,
                      label: l.priceLabel,
                      ltr: true,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        return (n == null || n < 0 || n > 1000000) ? l.errPrice : null;
                      },
                    ),
                    const SizedBox(height: Space.s12),
                    DropdownButtonFormField<String>(
                      value: cats.any((c) => c.id == _categoryId) ? _categoryId : null,
                      decoration: InputDecoration(
                        labelText: l.categoryLabel,
                        filled: true,
                        fillColor: p.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.lg)),
                      ),
                      items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name.of(lang)))],
                      onChanged: (v) => setState(() => _categoryId = v ?? ''),
                    ),
                    const SizedBox(height: Space.s12),
                    _photoPicker(),
                    const SizedBox(height: Space.s12),
                    AppTextField(
                      controller: _image,
                      label: l.imageUrlLabel,
                      helper: l.imageUrlHelper,
                      ltr: true,
                      keyboardType: TextInputType.url,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return null;
                        return (s.startsWith('https://') && s.length <= 500) ? null : l.errImageUrl;
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.availableToday),
                      value: _available,
                      onChanged: (v) => setState(() => _available = v),
                    ),
                    const SizedBox(height: Space.s8),
                    Text(l.optionsTitle, style: text.titleMedium),
                    Text(l.optionsHelp, style: text.bodySmall?.copyWith(color: p.textMuted)),
                    const SizedBox(height: Space.s12),
                    for (var gi = 0; gi < _groups.length; gi++) ...[
                      _groupCard(gi),
                      const SizedBox(height: Space.s12),
                    ],
                    if (_groups.length < 10)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AppButton(
                          label: l.addOptionGroup,
                          icon: Icons.add_rounded,
                          kind: AppButtonKind.secondary,
                          expand: false,
                          onPressed: () => setState(() => _groups.add(_GroupDraft('', false, false, [_ChoiceDraft('', 0)]))),
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: Space.s16),
                      StatusBanner(message: _error!, kind: BannerKind.error),
                    ],
                    const SizedBox(height: Space.s24),
                    AppButton(label: l.save, loading: _busy, onPressed: _save),
                    if (widget.dish != null) ...[
                      const SizedBox(height: Space.s8),
                      AppButton(label: l.deleteDish, kind: AppButtonKind.text, onPressed: _busy ? null : _delete),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(int gi) {
    final l = context.l10n;
    final g = _groups[gi];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: AppTextField(controller: g.name, label: l.groupNameLabel)),
              IconButton(
                tooltip: l.removeGroup,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => setState(() => _groups.removeAt(gi).dispose()),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.optionRequiredTag),
            value: g.required,
            onChanged: (v) => setState(() => g.required = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.allowMultiple),
            value: g.multi,
            onChanged: (v) => setState(() => g.multi = v),
          ),
          for (var ci = 0; ci < g.choices.length; ci++)
            Padding(
              padding: const EdgeInsets.only(top: Space.s8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: AppTextField(controller: g.choices[ci].name, label: l.choiceNameLabel)),
                  const SizedBox(width: Space.s8),
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      controller: g.choices[ci].price,
                      label: l.extraPriceLabel,
                      ltr: true,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    tooltip: l.removeChoice,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: g.choices.length > 1 ? () => setState(() => g.choices.removeAt(ci).dispose()) : null,
                  ),
                ],
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: g.choices.length < 20 ? () => setState(() => g.choices.add(_ChoiceDraft('', 0))) : null,
              icon: const Icon(Icons.add_rounded),
              label: Text(l.addChoice),
            ),
          ),
        ],
      ),
    );
  }
}
