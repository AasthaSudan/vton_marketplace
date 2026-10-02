import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
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
                              Text(
                                'No address selected',
                                style: AppTypography.body(
                                  color: colors.textSecondary,
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
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 18,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        selectedAddress.name,
                                        style: AppTypography.bodyMedium(
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
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

                  // Step 2: Delivery Option
                  _buildSectionTitle('2. Delivery Option'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(color: colors.border.withOpacity(0.8)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.accentSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.rocket_launch_outlined,
                            color: colors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cart.shipmentCount > 1
                                    ? 'Delivered in ${cart.shipmentCount} shipments'
                                    : 'Delivered by your brand',
                                style: AppTypography.bodyMedium(
                                  weight: FontWeight.w600,
                                ).copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Each brand packs and ships its own items. '
                                "You'll get tracking for every shipment.",
                                style: AppTypography.caption(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          cart.shippingFee == 0
                              ? 'FREE'
                              : CurrencyFormatter.format(cart.shippingFee),
                          style: AppTypography.label(
                            color: cart.shippingFee == 0
                                ? colors.success
                                : colors.textPrimary,
                            weight: FontWeight.w700,
                          ).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Step 3: Payment Method
                  _buildSectionTitle('3. Payment Method'),
                  const SizedBox(height: 10),
                  ..._paymentOptions.map((opt) {
                    final isSelected = _selectedPaymentMethod == opt['id'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PressableScale(
                        onTap: () => setState(
                          () => _selectedPaymentMethod = opt['id'] as String,
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
                                        : colors.textSecondary.withOpacity(0.4),
                                    size: 20,
                                  ),
                                ],
                              ),
                              if (isSelected && opt['id'] == 'UPI') ...[
                                const SizedBox(height: 12),
                                Divider(color: colors.border.withOpacity(0.5)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: ['Google Pay', 'PhonePe', 'Paytm']
                                      .map((app) {
                                        final isAppSelected =
                                            _selectedUpiApp == app;
                                        return PressableScale(
                                          onTap: () => setState(
                                            () => _selectedUpiApp = app,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
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
                            Text(
                              'Grand Total',
                              style: AppTypography.h3(
                                color: colors.textPrimary,
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
        Text(
          label,
          style: AppTypography.caption(
            color: isHighlight ? colors.success : colors.textSecondary,
          ),
        ),
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
