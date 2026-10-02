import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/secondary_button.dart';
import '../../address/presentation/providers/address_providers.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';
import '../../orders/presentation/providers/order_providers.dart';

class OrderSuccessScreen extends ConsumerWidget {
  final String orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: orderAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (order) {
              final orderNum = order?.orderNumber ?? orderId;

              // Centred on tall phones, scrollable on short ones.
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          // Animated celebration circle
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: colors.success.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: colors.success,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          Text(
                            ClothsyCopy.orderPlacedTitle,
                            textAlign: TextAlign.center,
                            style: AppTypography.h1(color: colors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ClothsyCopy.orderPlacedMessage,
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Order Card Details
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: AppRadius.cardRadius,
                              border: Border.all(
                                color: colors.border.withOpacity(0.8),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Order number',
                                        style: AppTypography.caption(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      orderNum,
                                      style: AppTypography.bodyMedium(
                                        color: colors.primary,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Divider(color: colors.border.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order total',
                                      style: AppTypography.caption(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      order == null
                                          ? '—'
                                          : CurrencyFormatter.format(
                                              order.total,
                                            ),
                                      style: AppTypography.bodyMedium(
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // One line per brand: each ships on its own.
                                if (order != null)
                                  for (final part in order.sellerOrders)
                                    _ShipmentLine(
                                      sellerId: part.sellerId,
                                      sellerName: part.sellerName,
                                      pinCode: order.shippingAddress.pinCode,
                                    ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Payment',
                                      style: AppTypography.caption(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        order == null
                                            ? '—'
                                            : '${order.paymentMethod} · ${order.paymentStatus.label}',
                                        textAlign: TextAlign.end,
                                        style: AppTypography.bodyMedium(
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),

                          // Actions
                          PrimaryButton(
                            text: 'Track Order',
                            icon: const Icon(
                              Icons.location_searching_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: () => context.go('/orders/$orderId'),
                          ),
                          const SizedBox(height: 12),
                          SecondaryButton(
                            text: 'Continue Shopping',
                            onPressed: () => context.go('/'),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShipmentLine extends ConsumerWidget {
  final String sellerId;
  final String sellerName;
  final String pinCode;

  const _ShipmentLine({
    required this.sellerId,
    required this.sellerName,
    required this.pinCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final seller = ref.watch(sellerProvider(sellerId)).asData?.value;
    final pin = ref.watch(pinServiceabilityProvider(pinCode)).asData?.value;
    final when = pin != null && pin.serviceable
        ? 'Arrives by ${arrivesByLabel(dispatchDays: seller?.dispatchDays ?? 2, transitDays: pin.etaDays)}'
        : 'Ships in ${seller?.dispatchDays ?? 2} working days';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sellerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium(weight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              when,
              textAlign: TextAlign.end,
              style: AppTypography.caption(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
