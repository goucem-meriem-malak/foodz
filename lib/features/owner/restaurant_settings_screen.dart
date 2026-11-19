import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/page_list.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/models/app_settings.dart';
import '../../data/providers.dart';

/// Owner only: name, delivery fee, minimum order, preparation time, contact, and
/// the switch that stops new orders.
class RestaurantSettingsScreen extends ConsumerWidget {
  const RestaurantSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    return PageList(
      title: l.navRestaurant,
      children: [
        if (settings.isLoading)
          const ListSkeleton(count: 2, height: 160)
        else
          // Keyed by the stored values so the form refreshes after a save.
          _SettingsForm(initial: settings.valueOrNull ?? AppSettings.defaults),
      ],
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});
  final AppSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial.restaurantName);
  late final _fee = TextEditingController(text: '${widget.initial.deliveryFee}');
  late final _min = TextEditingController(text: '${widget.initial.minOrder}');
  late final _prep = TextEditingController(text: '${widget.initial.defaultPrepMinutes}');
  late final _phone = TextEditingController(text: widget.initial.contactPhone);
  late final _email = TextEditingController(text: widget.initial.contactEmail);
  late bool _accepting = widget.initial.acceptingOrders;
  late final Map<int, DayHours> _hours =
      widget.initial.hours.isEmpty ? AppSettings.defaultWeek : Map<int, DayHours>.of(widget.initial.hours);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _fee, _min, _prep, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _intIn(String? v, int min, int max) {
    final n = int.tryParse((v ?? '').trim());
    return (n == null || n < min || n > max) ? context.l10n.errNumberRange(min, max) : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(settingsRepositoryProvider).save(AppSettings(
            restaurantName: _name.text,
            deliveryFee: int.parse(_fee.text.trim()),
            minOrder: int.parse(_min.text.trim()),
            defaultPrepMinutes: int.parse(_prep.text.trim()),
            acceptingOrders: _accepting,
            contactPhone: _phone.text,
            contactEmail: _email.text,
            hours: _hours,
          ));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.savedMessage)));
    } catch (_) {
      if (mounted) setState(() => _error = l.errSave);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _dayName(int day) {
    final l = context.l10n;
    return switch (day) {
      1 => l.dayMon,
      2 => l.dayTue,
      3 => l.dayWed,
      4 => l.dayThu,
      5 => l.dayFri,
      6 => l.daySat,
      _ => l.daySun,
    };
  }

  static String _clock(int minutes) {
    final m = minutes == 1440 ? 0 : minutes;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime(int day, {required bool opening}) async {
    final current = _hours[day] ?? const DayHours();
    final minutes = opening ? current.open : current.close;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (minutes % 1440) ~/ 60, minute: minutes % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    final value = picked.hour * 60 + picked.minute;
    setState(() => _hours[day] = opening ? current.copyWith(open: value) : current.copyWith(close: value));
  }

  Widget _dayRow(int day) {
    final l = context.l10n;
    final p = context.palette;
    final d = _hours[day] ?? const DayHours();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s8),
      child: AppCard(
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(_dayName(day), style: text.titleSmall)),
            if (d.closed)
              Expanded(flex: 4, child: Text(l.dayClosed, style: text.bodyMedium?.copyWith(color: p.textMuted)))
            else
              Expanded(
                flex: 4,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _pickTime(day, opening: true),
                      child: Text(_clock(d.open), textDirection: TextDirection.ltr),
                    ),
                    const Text('-'),
                    TextButton(
                      onPressed: () => _pickTime(day, opening: false),
                      child: Text(_clock(d.close), textDirection: TextDirection.ltr),
                    ),
                  ],
                ),
              ),
            Switch(
              value: !d.closed,
              onChanged: (open) => setState(() => _hours[day] = d.copyWith(closed: !open)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insights_rounded),
              title: Text(l.statsOpen),
              onTap: () => context.push('/stats'),
            ),
          ),
          const SizedBox(height: Space.s12),
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.acceptingOrders),
              subtitle: Text(l.acceptingOrdersHelp),
              value: _accepting,
              onChanged: (v) => setState(() => _accepting = v),
            ),
          ),
          const SizedBox(height: Space.s16),
          AppTextField(
            controller: _name,
            label: l.restaurantNameLabel,
            validator: (v) => (v ?? '').trim().isEmpty || v!.trim().length > 60 ? l.errRequired : null,
          ),
          const SizedBox(height: Space.s12),
          AppTextField(
            controller: _fee,
            label: l.deliveryFeeLabel,
            ltr: true,
            keyboardType: TextInputType.number,
            validator: (v) => _intIn(v, 0, 10000),
          ),
          const SizedBox(height: Space.s12),
          AppTextField(
            controller: _min,
            label: l.minOrderLabel,
            ltr: true,
            keyboardType: TextInputType.number,
            validator: (v) => _intIn(v, 0, 100000),
          ),
          const SizedBox(height: Space.s12),
          AppTextField(
            controller: _prep,
            label: l.defaultPrepLabel,
            ltr: true,
            keyboardType: TextInputType.number,
            validator: (v) => _intIn(v, 5, 120),
          ),
          const SizedBox(height: Space.s12),
          AppTextField(
            controller: _phone,
            label: l.contactPhoneLabel,
            ltr: true,
            keyboardType: TextInputType.phone,
            validator: (v) => (v ?? '').length > 20 ? l.errTooShortOrLong : null,
          ),
          const SizedBox(height: Space.s12),
          AppTextField(
            controller: _email,
            label: l.contactEmailLabel,
            ltr: true,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v ?? '').length > 100 ? l.errTooShortOrLong : null,
          ),
          const SizedBox(height: Space.s24),
          Text(l.hoursTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Space.s4),
          Text(l.hoursHelp, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.textMuted)),
          const SizedBox(height: Space.s12),
          for (var day = 1; day <= 7; day++) _dayRow(day),
          if (_error != null) ...[
            const SizedBox(height: Space.s16),
            StatusBanner(message: _error!, kind: BannerKind.error),
          ],
          const SizedBox(height: Space.s24),
          AppButton(label: l.save, loading: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
