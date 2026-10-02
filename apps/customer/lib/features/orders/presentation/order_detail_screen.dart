import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:clothsy_core/shared/widgets/buttons/clothsy_icon_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/secondary_button.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_bottom_sheet.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'providers/order_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  void _openCancelSheet(BuildContext context, WidgetRef ref, Order order) {
    String selectedReason = 'Ordered by mistake';
    final reasons = [
      'Ordered by mistake',
      'Need to change delivery address',
      'Selected wrong size or variant',
      'Expected faster delivery',
      'Found a better deal',
    ];

    ClothsyBottomSheet.show(
      context: context,
      title: 'Cancel Order',
      subtitle: 'Please select a reason for cancellation',
      child: StatefulBuilder(
        builder: (context, setState) {
          final colors = context.colors;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...reasons.map((r) {
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
                  text: 'Confirm Cancellation',
                  backgroundColor: colors.error,
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref
                        .read(ordersProvider.notifier)
                        .cancelOrder(order.id, selectedReason);
                    ref.invalidate(orderDetailProvider(order.id));
                    if (context.mounted) {
                      ClothsySnackbar.show(
                        context,
                        message:
                            'Order ${order.orderNumber} has been cancelled.',
                        type: SnackbarType.info,
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Order Details',
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

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Header Card: Order Number, Date, Status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: colors.border.withOpacity(0.6)),
                ),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            order.status.label.toUpperCase(),
                            style: AppTypography.label(
                              color: colors.primary,
                              weight: FontWeight.w700,
                            ).copyWith(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: AppTypography.caption(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tracking Stepper Timeline
              _buildSectionTitle('Delivery Progress'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: colors.border.withOpacity(0.6)),
                ),
                child: Column(
                  children: order.trackingSteps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    final isLast = index == order.trackingSteps.length - 1;

                    return _buildTimelineStep(context, step, isLast: isLast);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Items Ordered
              _buildSectionTitle('Items (${order.items.length})'),
              const SizedBox(height: 10),
              ...order.items.map((item) {
                return Container(
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
                        height: 74,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: colors.surfaceMuted,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CachedNetworkImage(
                          imageUrl:
                              item.variant.imageUrl ??
                              item.product.primaryImage,
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
                              CurrencyFormatter.format(
                                item.variant.price * item.quantity,
                              ),
                              style: AppTypography.price(
                                color: colors.textPrimary,
                              ).copyWith(fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),

              // Shipping Address
              _buildSectionTitle('Delivery Address'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: colors.border.withOpacity(0.6)),
                ),
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

              // Payment and Total Summary
              _buildSectionTitle('Payment Details'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: colors.border.withOpacity(0.6)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Payment Method', order.paymentMethod),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Payment Status', order.paymentStatus),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Subtotal',
                      CurrencyFormatter.format(order.subtotal),
                    ),
                    if (order.discount > 0) ...[
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Discount Applied',
                        '- ${CurrencyFormatter.format(order.discount)}',
                        isHighlight: true,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Shipping Fee',
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
                          'Total Amount Paid',
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
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons: Reorder & Cancel
              PrimaryButton(
                text: 'Reorder Items',
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
                    message:
                        '${order.items.length} items added to your shopping bag!',
                    type: SnackbarType.success,
                  );
                  context.push('/cart');
                },
              ),
              if (order.canBeCancelled) ...[
                const SizedBox(height: 12),
                SecondaryButton(
                  text: 'Cancel Order',
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.bodyMedium(
        weight: FontWeight.w700,
      ).copyWith(fontSize: 15),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.caption(
            color: isHighlight ? Colors.green : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium(
            weight: FontWeight.w600,
            color: isHighlight ? Colors.green : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep(
    BuildContext context,
    TrackingStep step, {
    bool isLast = false,
  }) {
    final colors = context.colors;
    final dotColor = step.isCompleted
        ? colors.success
        : (step.isCurrent ? colors.primary : colors.border);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Icon / Circle and Vertical Line
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
          // Step Text & Date
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
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
