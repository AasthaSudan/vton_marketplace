import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/panel_widgets.dart';
import 'order_actions.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String sellerOrderId;

  const OrderDetailScreen({super.key, required this.sellerOrderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return AsyncBody<List<SellerOrder>>(
      value: orders,
      onRetry: () => ref.invalidate(ordersProvider),
      builder: (all) {
        final order = all.where((o) => o.id == sellerOrderId).firstOrNull;
        if (order == null) {
          return PanelPage(
            title: 'Order not found',
            children: [
              TextButton(
                onPressed: () => context.go('/orders'),
                child: const Text('Back to orders'),
              ),
            ],
          );
        }
        return _Detail(order: order);
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  final SellerOrder order;

  const _Detail({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final actions = OrderActions(context);
    final next = nextStepButton(actions, order);
    final money = CurrencyFormatter.format;
    return PanelPage(
      title: order.reference,
      subtitle:
          '${orderStatuses[order.status]} · ordered ${formatDateTime(order.createdAt)}',
      onRefresh: () async => ref.invalidate(ordersProvider),
      actions: [
        TextButton.icon(
          onPressed: () => context.go('/orders'),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('All orders'),
        ),
        if (order.hasInvoice)
          OutlinedButton.icon(
            onPressed: () => actions.printDocuments(order),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print invoice & label'),
          ),
        if (order.canCancel)
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: colors.error),
            onPressed: () => actions.cancel(order),
            child: const Text('Cancel order'),
          ),
        ?next,
      ],
      children: [
        if (order.isLate(DateTime.now()))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'This order was due to be dispatched by '
              '${formatDate(order.dispatchBy)}. Late dispatch lowers your '
              'performance score.',
              style: AppTypography.bodyMedium(color: colors.error),
            ),
          ),
        PanelCard(
          title: 'Items',
          child: Column(
            children: [
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.imageUrl == null
                            ? Container(
                                width: 48,
                                height: 64,
                                color: colors.surfaceMuted,
                              )
                            : Image.network(
                                item.imageUrl!,
                                width: 48,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 48,
                                  height: 64,
                                  color: colors.surfaceMuted,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: AppTypography.bodyMedium(
                                color: colors.textPrimary,
                                weight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${item.variantTitle} · ${item.quantity} × '
                              '${money(item.unitPrice)}',
                              style: AppTypography.caption(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        money(item.lineTotal),
                        style: AppTypography.bodyMedium(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Shopper pays (incl. shipping, after Clothsy offers)',
                      style: AppTypography.caption(color: colors.textSecondary),
                    ),
                  ),
                  Text(
                    money(order.total),
                    style: AppTypography.h3(color: colors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
        ),
        PanelCard(
          title: 'Timeline',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(context, 'Ordered', formatDateTime(order.createdAt)),
              if (order.isOpen)
                _line(context, 'Dispatch by', formatDate(order.dispatchBy)),
              if (order.invoiceNumber != null)
                _line(context, 'Invoice', order.invoiceNumber!),
              if (order.shipment?.trackingNumber != null)
                _line(
                  context,
                  'Courier',
                  '${order.shipment!.carrier} · AWB '
                      '${order.shipment!.trackingNumber}',
                ),
              if (order.deliveredAt != null)
                _line(context, 'Delivered', formatDateTime(order.deliveredAt)),
              if (order.status == 'cancelled')
                _line(
                  context,
                  'Cancelled',
                  '${order.cancelReason ?? ''}'
                      '${order.cancelledBy == null ? '' : ' (by ${order.cancelledBy})'}',
                ),
            ],
          ),
        ),
        if (order.status == 'placed' || order.status == 'confirmed')
          Text(
            'The shopping address is printed on the label when you pack the '
            'order. If you cannot fulfil it, cancel before packing — the '
            'shopper is refunded automatically, and it counts against your '
            'performance score.',
            style: AppTypography.caption(color: colors.textSecondary),
          ),
      ],
    );
  }

  Widget _line(BuildContext context, String label, String value) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.label(color: colors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
