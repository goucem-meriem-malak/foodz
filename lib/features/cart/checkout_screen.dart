import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/security/validators.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/cart.dart';
import '../../data/providers.dart';
import '../orders/order_widgets.dart';

/// Delivery details, the "we will call you" notice, and placing the order.
/// Payment is cash on delivery, so nothing is charged here.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(appUserProvider).valueOrNull?.name ?? '');
  late final _phone = TextEditingController(text: ref.read(appUserProvider).valueOrNull?.phone ?? '');
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _area.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _len(String? v, int min, int max) {
    final l = context.l10n;
    final s = v?.trim() ?? '';
    if (s.isEmpty) return l.errRequired;
    if (s.length < min || s.length > max) return l.errTooShortOrLong;
    return null;
  }

  Future<void> _place() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final cart = ref.read(cartProvider);
    final cfg = ref.read(settingsProvider).valueOrNull ?? AppSettings.defaults;
    if (uid == null || cart.isEmpty) return;

    if (!cfg.openNow()) {
      setState(() => _error = l.closedBanner);
      return;
    }
    if (cartSubtotal(cart) < cfg.minOrder) {
      setState(() => _error = l.minOrderNotice(Fmt.money(cfg.minOrder, lang)));
      return;
    }
    // A dish may have been sold out or removed while it sat in the cart.
    final menu = ref.read(dishesProvider).valueOrNull ?? const [];
    for (final line in cart) {
      final live = menu.where((d) => d.id == line.dish.id).toList();
      if (live.isEmpty || !live.first.available) {
        setState(() => _error = l.dishUnavailable(line.name.of(lang)));
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(ordersRepositoryProvider).place(
            uid: uid,
            lines: cart,
            deliveryFee: cfg.deliveryFee,
            name: _name.text,
            phone: Validators.normalizePhone(_phone.text),
            area: _area.text,
            address: _address.text,
            note: _note.text,
          );
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      context.go('/home');
      context.push('/order/$id');
    } on FirebaseException catch (e) {
      if (mounted) setState(() => _error = e.code == 'permission-denied' ? l.errOrderDenied : l.errOrderFailed);
    } catch (_) {
      if (mounted) setState(() => _error = l.errOrderFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final cart = ref.watch(cartProvider);
    final cfg = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final subtotal = cartSubtotal(cart);

    return Scaffold(
      appBar: AppBar(title: Text(l.checkoutTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.s24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Layout.formWidth * 1.2),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The promise the customer must see before ordering.
                      Container(
                        padding: const EdgeInsets.all(Space.s16),
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(Radii.xl),
                          border: Border.all(color: p.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.phone_in_talk_rounded, color: p.primary),
                            const SizedBox(width: Space.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.callNoticeTitle, style: text.titleMedium),
                                  const SizedBox(height: Space.s4),
                                  Text(l.callNoticeBody, style: text.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.s24),
                      AppTextField(
                        controller: _name,
                        label: l.fullName,
                        icon: Icons.person_outline_rounded,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: (v) => Validators.name(v)?.text(l),
                      ),
                      const SizedBox(height: Space.s16),
                      AppTextField(
                        controller: _phone,
                        label: l.phone,
                        hint: l.phoneHint,
                        helper: l.phoneHelper,
                        icon: Icons.phone_outlined,
                        ltr: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (v) => Validators.phone(v)?.text(l),
                      ),
                      const SizedBox(height: Space.s16),
                      AppTextField(
                        controller: _area,
                        label: l.areaLabel,
                        hint: l.areaHint,
                        icon: Icons.location_city_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (v) => _len(v, 2, 60),
                      ),
                      const SizedBox(height: Space.s16),
                      AppTextField(
                        controller: _address,
                        label: l.addressLabel,
                        hint: l.addressHint,
                        icon: Icons.home_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (v) => _len(v, 5, 250),
                      ),
                      const SizedBox(height: Space.s16),
                      AppTextField(
                        controller: _note,
                        label: l.noteLabel,
                        icon: Icons.edit_note_rounded,
                        textInputAction: TextInputAction.done,
                        validator: (v) => (v ?? '').length > 300 ? l.errTooShortOrLong : null,
                      ),
                      const SizedBox(height: Space.s24),
                      AppCard(
                        child: Column(
                          children: [
                            PriceRow(l.subtotal, Fmt.money(subtotal, lang)),
                            PriceRow(l.deliveryFee, Fmt.money(cfg.deliveryFee, lang)),
                            const Divider(),
                            PriceRow(l.total, Fmt.money(subtotal + cfg.deliveryFee, lang), bold: true),
                            const SizedBox(height: Space.s8),
                            Row(
                              children: [
                                Icon(Icons.payments_outlined, size: 18, color: p.textMuted),
                                const SizedBox(width: Space.s8),
                                Text(l.payOnDelivery, style: text.bodySmall?.copyWith(color: p.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Space.s16),
                        StatusBanner(message: _error!, kind: BannerKind.error),
                      ],
                      const SizedBox(height: Space.s24),
                      AppButton(label: l.placeOrder, loading: _busy, onPressed: cart.isEmpty ? null : _place),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
