import 'package:clothsy_core/core/utils/money_split.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';

/// Splits a bag into one [SellerOrder] per seller (Blueprint, fig. 17 & 21).
///
/// This is the single rule for how a checkout becomes seller orders, shared by
/// the mock repository and the tests; the database function that places real
/// orders implements the same maths (see supabase/migrations).
class OrderSplitter {
  OrderSplitter._();

  /// Letter suffix for the [index]-th seller order: A, B, C ... then numbers.
  static String suffix(int index) =>
      index < 26 ? String.fromCharCode(65 + index) : '${index + 1}';

  static List<SellerOrder> split({
    required String orderId,
    required String orderNumber,
    required List<CartLineItem> items,
    required int discount,
    required OrderStatus initialStatus,
    required DateTime placedAt,
    int shippingThreshold = 199900,
  }) {
    final summary = CartSummary(
      items: items,
      discountAmount: discount,
      shippingThreshold: shippingThreshold,
    );
    final groups = summary.sellerGroups;

    // A coupon can never discount more than the goods are worth.
    final subtotals = groups.map((g) => g.subtotal).toList();
    final goodsTotal = subtotals.fold<int>(0, (sum, v) => sum + v);
    final cappedDiscount = discount.clamp(0, goodsTotal);
    final shares = splitProportionally(cappedDiscount, subtotals);

    return [
      for (var i = 0; i < groups.length; i++)
        SellerOrder(
          id: '${orderId}_${suffix(i).toLowerCase()}',
          reference: '$orderNumber-${suffix(i)}',
          sellerId: groups[i].sellerId,
          sellerName: groups[i].sellerName,
          items: groups[i].items,
          subtotal: groups[i].subtotal,
          shippingFee: groups[i].shippingFee,
          discountShare: shares[i],
          status: initialStatus,
          trackingSteps: TrackingStep.timeline(
            status: initialStatus,
            sellerName: groups[i].sellerName,
            placedAt: placedAt,
          ),
        ),
    ];
  }
}
