import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:clothsy_core/shared/widgets/buttons/clothsy_icon_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import 'package:clothsy_core/shared/widgets/feedback/empty_state_view.dart';
import 'package:clothsy_core/shared/widgets/selectors/quantity_stepper.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'providers/cart_provider.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _couponController = TextEditingController();

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  void _applyCoupon() {
    final code = _couponController.text;
    if (code.trim().isEmpty) return;

    final success = ref.read(cartProvider.notifier).applyCoupon(code);
    if (success) {
      ClothsySnackbar.show(
        context,
        message: 'Promo coupon "$code" applied successfully!',
        type: SnackbarType.success,
      );
    } else {
      ClothsySnackbar.show(
        context,
        message: "That code isn't valid. Check it and try again.",
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Your bag (${cart.totalCount})',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
      ),
      body: cart.isEmpty
          ? EmptyStateView(
              icon: Icons.shopping_bag_outlined,
              title: ClothsyCopy.emptyBagTitle,
              message: ClothsyCopy.emptyBagMessage,
              actionText: 'Start exploring',
              onActionPressed: () => context.go('/explore'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    children: [
                      // One bag, grouped by seller — each ships separately.
                      ...cart.sellerGroups.map(
                        (group) => _buildSellerGroup(context, group),
                      ),
                      const SizedBox(height: 4),

                      // Promo Coupon Code Input
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: AppRadius.cardRadius,
                          border: Border.all(
                            color: colors.border.withOpacity(0.8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.discount_outlined,
                              color: colors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _couponController,
                                style: AppTypography.body(
                                  color: colors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: cart.couponCode != null
                                      ? 'Applied: ${cart.couponCode}'
                                      : 'Enter Coupon (e.g. CLOTHSY10)',
                                  hintStyle: AppTypography.body(
                                    color: colors.textSecondary.withOpacity(
                                      0.7,
                                    ),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (cart.couponCode != null)
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(cartProvider.notifier)
                                      .removeCoupon();
                                  _couponController.clear();
                                },
                                child: Text(
                                  'Remove',
                                  style: AppTypography.label(
                                    color: colors.error,
                                  ),
                                ),
                              )
                            else
                              TextButton(
                                onPressed: _applyCoupon,
                                style: TextButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  'Apply',
                                  style: AppTypography.label(
                                    color: colors.onPrimary,
                                  ).copyWith(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Price Summary Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: AppRadius.cardRadius,
                          border: Border.all(
                            color: colors.border.withOpacity(0.8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Summary',
                              style: AppTypography.bodyMedium(
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildSummaryRow(
                              'Subtotal',
                              CurrencyFormatter.format(cart.subtotal),
                            ),
                            if (cart.discountAmount > 0) ...[
                              const SizedBox(height: 8),
                              _buildSummaryRow(
                                'Coupon Discount (${cart.couponCode})',
                                '- ${CurrencyFormatter.format(cart.discountAmount)}',
                                isHighlight: true,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              cart.shipmentCount > 1
                                  ? 'Delivery (${cart.shipmentCount} shipments)'
                                  : 'Delivery',
                              cart.shippingFee == 0
                                  ? 'FREE'
                                  : CurrencyFormatter.format(cart.shippingFee),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Total Amount',
                                    style: AppTypography.h3(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  CurrencyFormatter.format(cart.total),
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
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // Sticky Bottom Checkout Button
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.border.withOpacity(0.6)),
                    ),
                  ),
                  child: PrimaryButton(
                    text:
                        'Proceed to Checkout • ${CurrencyFormatter.format(cart.total)}',
                    trailingIcon: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: () => context.push('/checkout'),
                  ),
                ),
              ],
            ),
    );
  }

  /// One seller's items with its own shipment summary underneath.
  Widget _buildSellerGroup(BuildContext context, SellerBagGroup group) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(
                      color: colors.textPrimary,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  group.shippingFee == 0
                      ? 'Free delivery'
                      : 'Delivery ${CurrencyFormatter.format(group.shippingFee)}',
                  style: AppTypography.caption(
                    color: group.shippingFee == 0
                        ? colors.success
                        : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ...group.items.map((item) => _buildCartItemCard(context, item)),
          if (group.amountToFreeShipping > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 2),
              child: Text(
                'Add ${CurrencyFormatter.format(group.amountToFreeShipping)} more '
                'from ${group.sellerName} for free delivery.',
                style: AppTypography.caption(color: colors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartLineItem item) {
    final colors = context.colors;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(cartProvider.notifier).removeFromCart(item.id);
        ClothsySnackbar.show(
          context,
          message: '${item.product.title} removed from bag',
          type: SnackbarType.info,
        );
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: AppRadius.cardRadius,
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: colors.border.withOpacity(0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product thumbnail
            Container(
              width: 82,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: colors.surfaceMuted,
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: item.variant.imageUrl ?? item.product.primaryImage,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            // Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.product.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium(
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ClothsyIconButton(
                        size: 28,
                        borderColor: Colors.transparent,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .removeFromCart(item.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${item.variant.size} • ${item.variant.colorName}',
                    style: AppTypography.caption(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  // Price and stepper share a row when there is room; on the
                  // narrowest phones the stepper drops below the price.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final price = Text(
                        CurrencyFormatter.format(item.variant.price),
                        maxLines: 1,
                        style: AppTypography.price(
                          color: colors.textPrimary,
                        ).copyWith(fontSize: 16),
                      );
                      final stepper = QuantityStepper(
                        height: 32,
                        value: item.quantity,
                        onChanged: (newQty) {
                          ref
                              .read(cartProvider.notifier)
                              .updateQuantity(item.id, newQty);
                        },
                      );
                      if (constraints.maxWidth < 180) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [price, const SizedBox(height: 8), stepper],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: price),
                          const SizedBox(width: 8),
                          stepper,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption(
              color: isHighlight ? colors.success : colors.textSecondary,
              weight: isHighlight ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: AppTypography.bodyMedium(
            color: isHighlight ? colors.success : colors.textPrimary,
            weight: isHighlight ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
