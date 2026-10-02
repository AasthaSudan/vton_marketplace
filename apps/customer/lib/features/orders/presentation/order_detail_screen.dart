import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'package:clothsy_core/features/orders/domain/repositories/order_repository.dart';
import 'package:clothsy_core/shared/widgets/buttons/clothsy_icon_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/secondary_button.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_bottom_sheet.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import 'providers/order_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  static const _cancelReasons = [
    'Ordered by mistake',
    'Need to change delivery address',
    'Selected wrong size or variant',
    'Expected faster delivery',
    'Found a better deal',
  ];

  /// Asks for a reason, then cancels either one seller order ([part]) or every
  /// part that can still be cancelled.
  void _openCancelSheet(
    BuildContext context,
    WidgetRef ref,
    Order order, {
    SellerOrder? part,
  }) {
    String selectedReason = _cancelReasons.first;

    ClothsyBottomSheet.show(
      context: context,
      title: part == null ? 'Cancel order' : 'Cancel ${part.sellerName} order',
      subtitle: 'Please select a reason for cancellation',
      child: StatefulBuilder(
        builder: (context, setState) {
          final colors = context.colors;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._cancelReasons.map((r) {
                  final isSelected = selectedReason == r;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? colors.primary : colors.textSecondary,
                    ),
                    title: Text(
                      r,
                      style: AppTypography.body(color: colors.textPrimary),
                    ),
                    onTap: () => setState(() => selectedReason = r),
                  );
                }),
                const SizedBox(height: 20),
                PrimaryButton(
                  text: 'Confirm cancellation',
                  backgroundColor: colors.error,
                  onPressed: () async {
                    Navigator.pop(context);
                    await _cancel(context, ref, order, part, selectedReason);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Order order,
    SellerOrder? part,
    String reason,
  ) async {
    final notifier = ref.read(ordersProvider.notifier);
    try {
      final updated = part == null
          ? await notifier.cancelOrder(order.id, reason)
          : await notifier.cancelSellerOrder(order.id, part.id, reason);
      ref.invalidate(orderDetailProvider(order.id));
      if (!context.mounted) return;

      final refund = part == null
          ? updated.refundAmount - order.refundAmount
          : (updated.sellerOrderById(part.id)?.total ?? 0);
      final prepaid = updated.paymentStatus != PaymentStatus.cashOnDelivery;
      final what = part == null
          ? 'Order ${order.orderNumber} is cancelled.'
          : '${part.sellerName} order cancelled.';
      ClothsySnackbar.show(
        context,
        message: prepaid && refund > 0
            ? '$what ${ClothsyCopy.refundStarted(amount: CurrencyFormatter.format(refund), destination: order.method.refundDestination)}'
            : what,
        type: SnackbarType.info,
      );
    } on OrderException catch (e) {
      if (!context.mounted) return;
      ClothsySnackbar.show(
        context,
        message: e.message,
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Order details',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ClothsyIconButton(
            size: 38,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: colors.primary,
            ),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading order: $err')),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }

          final dateStr = DateFormat(
            'dd MMMM yyyy, hh:mm a',
          ).format(order.orderDate);
          final multiSeller = order.sellerOrders.length > 1;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order ${order.orderNumber}',
                          style: AppTypography.h3(color: colors.textPrimary),
                        ),
                        _StatusChip(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: AppTypography.caption(color: colors.textSecondary),
                    ),
                    if (multiSeller) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Your order ships in ${order.sellerOrders.length} '
                        'separate shipments, one from each brand.',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              for (final part in order.sellerOrders) ...[
                _SellerOrderSection(
                  part: part,
                  showCancel: multiSeller && part.canBeCancelled,
                  onCancel: () =>
                      _openCancelSheet(context, ref, order, part: part),
                ),
                const SizedBox(height: 20),
              ],

              _sectionTitle('Delivery address'),
              const SizedBox(height: 10),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.shippingAddress.name,
                      style: AppTypography.bodyMedium(weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.shippingAddress.phone,
                      style: AppTypography.caption(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.shippingAddress.formattedAddress,
                      style: AppTypography.body(color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _sectionTitle('Payment details'),
              const SizedBox(height: 10),
              _Card(
                child: Column(
                  children: [
                    _SummaryRow('Payment method', order.paymentMethod),
                    const SizedBox(height: 8),
                    _SummaryRow('Payment status', order.paymentStatus.label),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      'Subtotal',
                      CurrencyFormatter.format(order.subtotal),
                    ),
                    if (order.discount > 0) ...[
                      const SizedBox(height: 8),
                      _SummaryRow(
                        'Discount applied',
                        '- ${CurrencyFormatter.format(order.discount)}',
                        isHighlight: true,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _SummaryRow(
                      'Delivery',
                      order.shippingFee == 0
                          ? 'FREE'
                          : CurrencyFormatter.format(order.shippingFee),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.paymentStatus == PaymentStatus.cashOnDelivery
                              ? 'Total to pay on delivery'
                              : 'Total',
                          style: AppTypography.h3(color: colors.textPrimary),
                        ),
                        Text(
                          CurrencyFormatter.format(order.total),
                          style: AppTypography.h2(
                            color: colors.primary,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (order.refundAmount > 0) ...[
                      const SizedBox(height: 10),
                      _SummaryRow(
                        'Refund started',
                        CurrencyFormatter.format(order.refundAmount),
                        isHighlight: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              PrimaryButton(
                text: 'Reorder items',
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: () {
                  for (final item in order.items) {
                    ref
                        .read(cartProvider.notifier)
                        .addToCart(
                          item.product,
                          item.variant,
                          quantity: item.quantity,
                        );
                  }
                  ClothsySnackbar.show(
                    context,
                    message: '${order.items.length} items are in your bag.',
                    type: SnackbarType.success,
                  );
                  context.go('/bag');
                },
              ),
              if (order.canBeCancelled) ...[
                const SizedBox(height: 12),
                SecondaryButton(
                  text: multiSeller
                      ? 'Cancel all remaining parts'
                      : 'Cancel order',
                  textColor: colors.error,
                  borderColor: colors.error.withOpacity(0.5),
                  onPressed: () => _openCancelSheet(context, ref, order),
                ),
              ],
              const SizedBox(height: 36),
            ],
          );
        },
      ),
    );
  }

  static Widget _sectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.bodyMedium(
        weight: FontWeight.w700,
      ).copyWith(fontSize: 15),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border.withOpacity(0.6)),
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color color;
    switch (status) {
      case OrderStatus.delivered:
        color = colors.success;
      case OrderStatus.cancelled:
      case OrderStatus.returned:
        color = colors.error;
      case OrderStatus.pendingPayment:
        color = colors.warning;
      default:
        color = colors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: AppTypography.label(
          color: color,
          weight: FontWeight.w700,
        ).copyWith(fontSize: 10),
      ),
    );
  }
}

/// One seller's part of the order: status, tracking, items and shipment total.
class _SellerOrderSection extends StatelessWidget {
  final SellerOrder part;
  final bool showCancel;
  final VoidCallback onCancel;

  const _SellerOrderSection({
    required this.part,
    required this.showCancel,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.storefront_outlined, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                part.sellerName,
                style: AppTypography.bodyMedium(
                  weight: FontWeight.w700,
                ).copyWith(fontSize: 15),
              ),
            ),
            _StatusChip(status: part.status),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            '${part.reference} · ${part.itemCount} ${part.itemCount == 1 ? 'item' : 'items'}',
            style: AppTypography.caption(color: colors.textSecondary),
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            children: [
              for (var i = 0; i < part.trackingSteps.length; i++)
                _TimelineStep(
                  step: part.trackingSteps[i],
                  isLast: i == part.trackingSteps.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final item in part.items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: colors.border.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: colors.surfaceMuted,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl:
                        item.variant.imageUrl ?? item.product.primaryImage,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.title,
                        style: AppTypography.bodyMedium(
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Size: ${item.variant.size} • Qty: ${item.quantity}',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(item.lineTotal),
                        style: AppTypography.price(
                          color: colors.textPrimary,
                        ).copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This shipment',
                style: AppTypography.caption(color: colors.textSecondary),
              ),
              Text(
                CurrencyFormatter.format(part.total),
                style: AppTypography.bodyMedium(weight: FontWeight.w700),
              ),
            ],
          ),
        ),
        if (showCancel) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                foregroundColor: colors.error,
              ),
              child: Text(
                'Cancel this part',
                style: AppTypography.label(
                  color: colors.error,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _SummaryRow(this.label, this.value, {this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.caption(
            color: isHighlight ? colors.success : colors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.bodyMedium(
              weight: FontWeight.w600,
              color: isHighlight ? colors.success : colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final TrackingStep step;
  final bool isLast;

  const _TimelineStep({required this.step, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dotColor = step.isCompleted
        ? colors.success
        : (step.isCurrent ? colors.primary : colors.border);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: step.isCompleted
                      ? colors.success
                      : (step.isCurrent ? colors.primary : colors.surface),
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: step.isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : (step.isCurrent
                          ? Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: step.isCompleted ? colors.success : colors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          step.title,
                          style: AppTypography.bodyMedium(
                            weight: step.isCurrent
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: step.isCompleted || step.isCurrent
                                ? colors.textPrimary
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                      if (step.date != null)
                        Text(
                          DateFormat('dd MMM, hh:mm a').format(step.date!),
                          style: AppTypography.caption(
                            color: colors.textSecondary,
                          ).copyWith(fontSize: 10),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.description,
                    style: AppTypography.caption(
                      color: colors.textSecondary,
                    ).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
