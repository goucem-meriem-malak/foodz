import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/phone.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_list.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/status_banner.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/order.dart';
import '../../data/models/user_role.dart';
import '../../data/providers.dart';
import 'order_widgets.dart';
import 'receipt.dart';

/// Follow one order: progress, items, totals, delivery details, receipt.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        title: Text(order.valueOrNull == null ? l.ordersTitle : l.orderNumber(order.valueOrNull!.code)),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
      ),
      body: order.when(
        loading: () => const Padding(padding: EdgeInsets.all(Space.s24), child: ListSkeleton(count: 3, height: 140)),
        error: (_, __) => StateView(
          icon: Icons.lock_outline_rounded,
          isError: true,
          title: l.somethingWrongTitle,
          message: l.errNetwork,
          actionLabel: l.retry,
          onAction: () => ref.invalidate(orderProvider(orderId)),
        ),
        data: (o) => o == null
            ? StateView(icon: Icons.search_off_rounded, title: l.orderNotFound)
            : _Body(order: o),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});
  final Order order;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cancelOrderTitle),
        content: Text(l.cancelOrderBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.keepOrder)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.yesCancel)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(ordersRepositoryProvider).cancelByClient(order);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errGeneric)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final role = ref.watch(currentRoleProvider);
    final cfg = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;

    final isMine = order.clientUid == uid;
    final isAdmin = role == UserRole.admin || role == UserRole.owner;
    final isMyDelivery = role == UserRole.delivery && order.courierUid == uid;
    final mayReadContact = isMine || isAdmin || isMyDelivery;
    final contact = mayReadContact ? ref.watch(contactProvider(order.id)).valueOrNull : null;

    final eta = order.expectedReadyAt;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Space.s24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Layout.formWidth * 1.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      StatusChip(order.status),
                      const Spacer(),
                      Text(shortDateTime(order.createdAt), style: text.bodySmall?.copyWith(color: p.textMuted)),
                    ],
                  ),
                  const SizedBox(height: Space.s16),
                  if (order.status == OrderStatus.placed && isMine)
                    StatusBanner(message: l.waitingForCall),
                  if (order.status == OrderStatus.preparing && eta != null)
                    StatusBanner(message: l.readyAround(shortTime(eta))),
                  if (order.status == OrderStatus.outForDelivery && isMine)
                    StatusBanner(message: l.payCashNotice(Fmt.money(order.total, lang))),
                  if (order.status == OrderStatus.rejected)
                    StatusBanner(
                      kind: BannerKind.error,
                      message: l.statusRejected + ((order.rejectReason ?? '').isEmpty ? '' : '\n${l.reasonLabel(order.rejectReason!)}'),
                    ),
                  if (order.status == OrderStatus.cancelled)
                    StatusBanner(kind: BannerKind.error, message: l.statusCancelled),
                  if (!order.status.isFinal || order.status == OrderStatus.delivered) ...[
                    const SizedBox(height: Space.s16),
                    _Timeline(status: order.status),
                  ],
                  const SizedBox(height: Space.s24),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OrderLinesView(lines: order.lines, lang: lang),
                        const Divider(),
                        PriceRow(l.subtotal, Fmt.money(order.subtotal, lang)),
                        PriceRow(l.deliveryFee, Fmt.money(order.deliveryFee, lang)),
                        PriceRow(l.total, Fmt.money(order.total, lang), bold: true),
                      ],
                    ),
                  ),
                  if (contact != null || order.area.isNotEmpty) ...[
                    const SizedBox(height: Space.s16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.deliveryTo, style: text.titleSmall),
                          const SizedBox(height: Space.s8),
                          if (contact != null) ...[
                            Text(contact.name, style: text.bodyLarge),
                            Text('${order.area} · ${contact.address}', style: text.bodyMedium),
                            const SizedBox(height: Space.s4),
                            Text(contact.phone, style: text.bodyMedium, textDirection: TextDirection.ltr),
                          ] else
                            Text(order.area, style: text.bodyMedium),
                          if (order.note.isNotEmpty) ...[
                            const SizedBox(height: Space.s8),
                            Text('${l.noteLabel}: ${order.note}',
                                style: text.bodySmall?.copyWith(color: p.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.s24),
                  if (contact != null && !isMine && (isAdmin || isMyDelivery)) ...[
                    AppButton(
                      icon: Icons.call_rounded,
                      label: l.callName(contact.name),
                      kind: AppButtonKind.secondary,
                      onPressed: () => callPhone(context, contact.phone),
                    ),
                    const SizedBox(height: Space.s12),
                  ],
                  if (contact != null &&
                      order.status != OrderStatus.rejected &&
                      order.status != OrderStatus.cancelled &&
                      (isMine || isAdmin))
                    AppButton(
                      icon: Icons.picture_as_pdf_rounded,
                      label: l.receiptButton,
                      kind: AppButtonKind.secondary,
                      onPressed: () => showReceipt(
                        context,
                        order: order,
                        contact: contact,
                        settings: cfg,
                        lang: lang,
                        labels: {
                          'receipt': l.receiptTitle,
                          'customer': l.customerLabel,
                          'subtotal': l.subtotal,
                          'delivery': l.deliveryFee,
                          'total': l.total,
                          'payment': l.receiptPayment,
                          'thanks': l.receiptThanks,
                        },
                      ),
                    ),
                  if (isMine && order.status == OrderStatus.placed) ...[
                    const SizedBox(height: Space.s12),
                    AppButton(
                      label: l.cancelOrderButton,
                      kind: AppButtonKind.text,
                      onPressed: () => _cancel(context, ref),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical progress: placed, confirmed, preparing, ready, on its way, delivered.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});
  final OrderStatus status;

  static const _steps = [
    OrderStatus.placed,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final current = _steps.indexOf(status);
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= current ? p.primary : Colors.transparent,
                      border: Border.all(color: i <= current ? p.primary : p.textMuted.withValues(alpha: 0.5), width: 2),
                    ),
                    child: i < current || status == OrderStatus.delivered
                        ? Icon(Icons.check_rounded, size: 16, color: p.onPrimary)
                        : null,
                  ),
                  const SizedBox(width: Space.s12),
                  Text(
                    statusLabel(l, _steps[i]),
                    style: text.bodyLarge?.copyWith(
                      color: i <= current ? p.text : p.textMuted,
                      fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
