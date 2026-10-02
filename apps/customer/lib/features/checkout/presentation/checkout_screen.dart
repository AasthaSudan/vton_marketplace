import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/constants/app_constants.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/features/address/domain/entities/pin_serviceability.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';
import 'package:clothsy_core/shared/widgets/buttons/clothsy_icon_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import '../../address/presentation/address_list_screen.dart';
import '../../address/presentation/providers/address_providers.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import '../../orders/presentation/providers/order_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedPaymentMethod = 'UPI'; // UPI, Card, NetBanking, COD
  String _selectedUpiApp = 'Google Pay';
  bool _isPlacingOrder = false;

  final List<Map<String, dynamic>> _paymentOptions = const [
    {
      'id': 'UPI',
      'title': 'Instant UPI Payment',
      'subtitle': 'Google Pay, PhonePe, Paytm, or any UPI ID',
      'icon': Icons.flash_on_rounded,
    },
    {
      'id': 'Card',
      'title': 'Credit or Debit Card',
      'subtitle': 'Visa, Mastercard, RuPay, Diners & Amex',
      'icon': Icons.credit_card_rounded,
    },
    {
      'id': 'NetBanking',
      'title': 'Net Banking',
      'subtitle': 'All major Indian banks supported',
      'icon': Icons.account_balance_rounded,
    },
    {
      'id': 'COD',
      'title': 'Cash on Delivery',
      'subtitle': 'Pay in cash upon doorstep delivery',
      'icon': Icons.payments_outlined,
    },
  ];

  Future<void> _handlePlaceOrder() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated && !auth.isGuest) {
      context.push('/login?redirect=/checkout');
      return;
    }

    final address = ref.read(selectedAddressProvider);
    if (address == null) {
      ClothsySnackbar.show(
        context,
        message: 'Please choose or add a delivery address',
        type: SnackbarType.error,
      );
      return;
    }

    final cart = ref.read(cartProvider);
    PinServiceability? pin;
    try {
      pin = await ref.read(pinServiceabilityProvider(address.pinCode).future);
    } catch (_) {
      pin = null; // The order service checks the PIN again anyway.
    }
    if (!mounted) return;
    if (pin != null && !pin.serviceable) {
      ClothsySnackbar.show(
        context,
        message:
            "We don't deliver to ${address.pinCode} yet. "
            'Please choose another address.',
        type: SnackbarType.error,
      );
      return;
    }
    final codReason = _selectedPaymentMethod == 'COD'
        ? _codBlockedReason(cart.total, pin)
        : null;
    if (codReason != null) {
      ClothsySnackbar.show(
        context,
        message: '$codReason Please pick another way to pay.',
        type: SnackbarType.error,
      );
      return;
    }
    if (cart.isEmpty) {
      ClothsySnackbar.show(
        context,
        message: ClothsyCopy.emptyBagTitle,
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    final PlaceOrderResult result;
    try {
      result = await ref
          .read(ordersProvider.notifier)
          .placeOrder(
            cart: cart,
            address: address,
            method: _paymentMethodFor(_selectedPaymentMethod),
            upiApp: _selectedUpiApp,
            customerName: address.name,
            customerPhone: address.phone,
          );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
    if (!mounted) return;

    switch (result) {
      case OrderPlaced(:final order):
        // Clear the bag only once the order is confirmed.
        ref.read(cartProvider.notifier).clearCart();
        context.go('/order-success/${order.id}');
      case PaymentNotCompleted(:final message, :final cancelledByCustomer):
        ClothsySnackbar.show(
          context,
          message: message,
          type: cancelledByCustomer ? SnackbarType.info : SnackbarType.error,
        );
      case OrderRejected(:final message):
        ClothsySnackbar.show(
          context,
          message: message,
          type: SnackbarType.error,
        );
    }
  }

  PaymentMethod _paymentMethodFor(String id) {
    switch (id) {
      case 'Card':
        return PaymentMethod.card;
      case 'NetBanking':
        return PaymentMethod.netBanking;
      case 'COD':
        return PaymentMethod.cashOnDelivery;
      default:
        return PaymentMethod.upi;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cart = ref.watch(cartProvider);
    final selectedAddress = ref.watch(selectedAddressProvider);
    final pin = selectedAddress == null
        ? null
        : ref
              .watch(pinServiceabilityProvider(selectedAddress.pinCode))
              .asData
              ?.value;
    final codBlockedReason = _codBlockedReason(cart.total, pin);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Checkout',
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                children: [
                  // Step 1: Delivery Address
                  _buildSectionTitle('1. Delivery Address'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(color: colors.border.withOpacity(0.8)),
                    ),
                    child: selectedAddress == null
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'No address selected',
                                  style: AppTypography.body(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AddressListScreen(
                                        isSelectingForCheckout: true,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Add Address',
                                  style: AppTypography.label(
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 18,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            selectedAddress.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.bodyMedium(
                                              weight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PressableScale(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AddressListScreen(
                                                isSelectingForCheckout: true,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Change',
                                      style:
                                          AppTypography.caption(
                                            color: colors.primary,
                                            weight: FontWeight.w700,
                                          ).copyWith(
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                selectedAddress.formattedAddress,
                                style: AppTypography.body(
                                  color: colors.textSecondary,
                                ).copyWith(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedAddress.phone,
                                style: AppTypography.caption(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Step 2: one shipment per brand (Blueprint fig. 17).
                  _buildSectionTitle('2. Delivery'),
                  const SizedBox(height: 10),
                  if (pin != null && !pin.serviceable)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.warning.withOpacity(0.1),
                        borderRadius: AppRadius.cardRadius,
                        border: Border.all(color: colors.warning),
                      ),
                      child: Text(
                        "We don't deliver to ${pin.pinCode} yet. Choose "
                        'another address to place this order.',
                        style: AppTypography.body(color: colors.textPrimary),
                      ),
                    ),
                  for (final group in cart.sellerGroups)
                    _ShipmentCard(group: group, pin: pin),
                  const SizedBox(height: 14),

                  // Step 3: Payment Method
                  _buildSectionTitle('3. Payment Method'),
                  const SizedBox(height: 10),
                  ..._paymentOptions.map((opt) {
                    final isSelected = _selectedPaymentMethod == opt['id'];
                    final blockedReason = opt['id'] == 'COD'
                        ? codBlockedReason
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Opacity(
                        opacity: blockedReason == null ? 1 : 0.5,
                        child: PressableScale(
                          onTap: blockedReason != null
                              ? () => ClothsySnackbar.show(
                                  context,
                                  message: blockedReason,
                                )
                              : () => setState(
                                  () => _selectedPaymentMethod =
                                      opt['id'] as String,
                                ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: AppRadius.cardRadius,
                              border: Border.all(
                                color: isSelected
                                    ? colors.primary
                                    : colors.border.withOpacity(0.6),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      opt['icon'] as IconData,
                                      color: colors.primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opt['title'] as String,
                                            style: AppTypography.bodyMedium(
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            blockedReason ??
                                                opt['subtitle'] as String,
                                            style: AppTypography.caption(
                                              color: colors.textSecondary,
                                            ).copyWith(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_off,
                                      color: isSelected
                                          ? colors.primary
                                          : colors.textSecondary.withOpacity(
                                              0.4,
                                            ),
                                      size: 20,
                                    ),
                                  ],
                                ),
                                if (isSelected && opt['id'] == 'UPI') ...[
                                  const SizedBox(height: 12),
                                  Divider(
                                    color: colors.border.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: ['Google Pay', 'PhonePe', 'Paytm']
                                        .map((app) {
                                          final isAppSelected =
                                              _selectedUpiApp == app;
                                          return PressableScale(
                                            onTap: () => setState(
                                              () => _selectedUpiApp = app,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isAppSelected
                                                    ? colors.primary
                                                    : colors.surfaceMuted,
                                                borderRadius:
                                                    BorderRadius.circular(100),
                                              ),
                                              child: Text(
                                                app,
                                                style: AppTypography.caption(
                                                  color: isAppSelected
                                                      ? colors.onPrimary
                                                      : colors.textPrimary,
                                                  weight: FontWeight.w600,
                                                ).copyWith(fontSize: 11),
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),

                  // Order Summary Breakdown
                  _buildSectionTitle('4. Order Summary'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(color: colors.border.withOpacity(0.8)),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow(
                          'Items Subtotal (${cart.totalCount})',
                          CurrencyFormatter.format(cart.subtotal),
                        ),
                        if (cart.discountAmount > 0) ...[
                          const SizedBox(height: 8),
                          _buildPriceRow(
                            'Coupon Discount (${cart.couponCode})',
                            '- ${CurrencyFormatter.format(cart.discountAmount)}',
                            isHighlight: true,
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (cart.shipmentCount > 1)
                          ...cart.sellerGroups.map(
                            (group) => Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildPriceRow(
                                'Shipment from ${group.sellerName}',
                                group.shippingFee == 0
                                    ? 'FREE'
                                    : CurrencyFormatter.format(
                                        group.shippingFee,
                                      ),
                              ),
                            ),
                          )
                        else ...[
                          const SizedBox(height: 8),
                          _buildPriceRow(
                            'Delivery',
                            cart.shippingFee == 0
                                ? 'FREE'
                                : CurrencyFormatter.format(cart.shippingFee),
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Grand Total',
                                style: AppTypography.h3(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
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

            // Sticky Bottom Button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.border.withOpacity(0.6)),
                ),
              ),
              child: PrimaryButton(
                text:
                    'Pay ${CurrencyFormatter.format(cart.total)} & Place Order',
                isLoading: _isPlacingOrder,
                trailingIcon: const Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: _handlePlaceOrder,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Why cash on delivery cannot be used for this order, if it cannot.
  String? _codBlockedReason(int total, PinServiceability? pin) {
    if (pin != null && pin.serviceable && !pin.codAvailable) {
      return 'Cash on delivery is not available for this PIN code.';
    }
    if (total > AppConstants.codMaxOrderValue) {
      return 'Cash on delivery is available on orders up to '
          '${CurrencyFormatter.format(AppConstants.codMaxOrderValue)}.';
    }
    return null;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.bodyMedium(
        weight: FontWeight.w700,
      ).copyWith(fontSize: 15),
    );
  }

  Widget _buildPriceRow(
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

/// One brand's shipment: its pieces, delivery charge and expected date.
class _ShipmentCard extends ConsumerWidget {
  final SellerBagGroup group;
  final PinServiceability? pin;

  const _ShipmentCard({required this.group, required this.pin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final seller = ref.watch(sellerProvider(group.sellerId)).asData?.value;
    final pin = this.pin;
    final arrives = pin != null && pin.serviceable
        ? 'Arrives by ${arrivesByLabel(dispatchDays: seller?.dispatchDays ?? 2, transitDays: pin.etaDays)}'
        : 'Ships in ${seller?.dispatchDays ?? 2} working days';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 16, color: colors.primary),
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
                    : CurrencyFormatter.format(group.shippingFee),
                style: AppTypography.caption(
                  color: group.shippingFee == 0
                      ? colors.success
                      : colors.textPrimary,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: group.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = group.items[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 42,
                        height: 56,
                        child: CachedNetworkImage(
                          imageUrl:
                              item.variant.imageUrl ??
                              item.product.primaryImage,
                          fit: BoxFit.cover,
                          errorWidget: (context, _, _) =>
                              ColoredBox(color: colors.surfaceMuted),
                        ),
                      ),
                      if (item.quantity > 1)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '×${item.quantity}',
                              style: AppTypography.caption(
                                color: colors.textPrimary,
                                weight: FontWeight.w700,
                              ).copyWith(fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 16,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$arrives • ${group.itemCount} '
                  '${group.itemCount == 1 ? 'item' : 'items'}',
                  style: AppTypography.caption(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
