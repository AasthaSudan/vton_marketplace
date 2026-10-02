import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';

/// Thrown when an order cannot be placed or changed (e.g. an item sold out).
///
/// [message] is ready to show; [code] is the machine-readable reason from
/// the order service (`OUT_OF_STOCK`, `PRICE_CHANGED`, `NOT_CANCELLABLE`...).
class OrderException implements Exception {
  final String message;
  final String? code;
  const OrderException(this.message, {this.code});

  @override
  String toString() => message;
}

abstract class OrderRepository {
  Future<List<Order>> getOrders();
  Future<Order?> getOrderById(String id);

  /// Places an order from the bag: split into one seller order per seller.
  ///
  /// Prepaid orders start as [OrderStatus.pendingPayment] with the stock held
  /// until [confirmPayment] or [failPayment]; cash-on-delivery orders are
  /// placed immediately. Totals are computed by the repository from [items] —
  /// [discount] is only the coupon amount the customer was shown.
  ///
  /// [idempotencyKey] makes retries safe: the same key returns the same order
  /// instead of placing a second one. When [expectedTotal] is given and the
  /// recomputed total differs, the order is refused with `PRICE_CHANGED`.
  Future<Order> createOrder({
    required List<CartLineItem> items,
    required Address address,
    required PaymentMethod method,
    required String paymentLabel,
    required int discount,
    String? couponCode,
    String? idempotencyKey,
    int? expectedTotal,
  });

  /// Marks a prepaid order as paid after the payment is confirmed. The
  /// gateway's [signature] and [gatewayOrderId] are verified server-side.
  Future<Order> confirmPayment(
    String orderId, {
    required String paymentRef,
    String? signature,
    String? gatewayOrderId,
  });

  /// Cancels an order whose payment failed and releases its held stock.
  Future<Order> failPayment(String orderId, String reason);

  /// Cancels every cancellable seller order of [orderId].
  Future<Order> cancelOrder(String orderId, String reason);

  /// Cancels a single seller order, leaving the others untouched.
  Future<Order> cancelSellerOrder(
    String orderId,
    String sellerOrderId,
    String reason,
  );
}
