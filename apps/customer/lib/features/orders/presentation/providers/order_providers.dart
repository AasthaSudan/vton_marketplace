import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'package:clothsy_core/features/orders/domain/repositories/order_repository.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';
import 'package:clothsy_shop/features/orders/data/repositories/mock_order_repository.dart';
import '../../../payments/presentation/providers/payment_providers.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return MockOrderRepository();
});

/// Result of trying to place an order from the bag.
sealed class PlaceOrderResult {
  const PlaceOrderResult();
}

/// The order is confirmed (paid online, or placed as cash on delivery).
class OrderPlaced extends PlaceOrderResult {
  final Order order;
  const OrderPlaced(this.order);
}

/// The customer was not charged: the payment failed or was closed. The bag is
/// untouched so they can retry or pick another method.
class PaymentNotCompleted extends PlaceOrderResult {
  final String message;
  final bool cancelledByCustomer;
  const PaymentNotCompleted(this.message, {this.cancelledByCustomer = false});
}

/// The order could not be created at all (e.g. an item sold out).
class OrderRejected extends PlaceOrderResult {
  final String message;
  const OrderRejected(this.message);
}

class OrdersNotifier extends Notifier<List<Order>> {
  @override
  List<Order> build() {
    _loadOrders();
    return [];
  }

  /// Orders whose payment failed or was abandoned are kept for audit but
  /// never shown to the customer.
  static List<Order> _visible(List<Order> orders) =>
      orders.where((o) => o.paymentStatus != PaymentStatus.failed).toList();

  Future<void> _loadOrders() async {
    final repo = ref.read(orderRepositoryProvider);
    final list = await repo.getOrders();
    if (!ref.mounted) return;
    state = _visible(list);
  }

  /// Places the order and, for prepaid methods, collects the payment:
  /// create (server computes totals) -> gateway -> confirm. The order only
  /// counts as paid after the repository confirms it.
  Future<PlaceOrderResult> placeOrder({
    required CartSummary cart,
    required Address address,
    required PaymentMethod method,
    required String customerName,
    required String customerPhone,
    String? upiApp,
  }) async {
    final repo = ref.read(orderRepositoryProvider);
    final gateway = ref.read(paymentGatewayProvider);

    final label = method == PaymentMethod.upi && upiApp != null
        ? 'UPI ($upiApp)'
        : method.label;

    final Order created;
    try {
      created = await repo.createOrder(
        items: cart.items,
        address: address,
        method: method,
        paymentLabel: label,
        discount: cart.discountAmount,
      );
    } on OrderException catch (e) {
      return OrderRejected(e.message);
    }

    if (!method.isPrepaid) {
      state = [created, ...state];
      return OrderPlaced(created);
    }

    final result = await gateway.pay(
      PaymentRequest(
        orderId: created.id,
        orderNumber: created.orderNumber,
        amount: created.total,
        method: method,
        customerName: customerName,
        customerPhone: customerPhone,
        upiApp: upiApp,
      ),
    );

    switch (result) {
      case PaymentSuccess(:final paymentRef):
        try {
          final confirmed = await repo.confirmPayment(
            created.id,
            paymentRef: paymentRef,
          );
          if (!ref.mounted) return OrderPlaced(confirmed);
          state = [confirmed, ...state];
          return OrderPlaced(confirmed);
        } on OrderException {
          // The gateway said yes but we could not confirm it. Never claim the
          // order is paid; the webhook / refund process settles the money.
          return const PaymentNotCompleted(ClothsyCopy.paymentFailed);
        }
      case PaymentFailure():
        await repo.failPayment(created.id, 'Payment failed');
        return const PaymentNotCompleted(ClothsyCopy.paymentFailed);
      case PaymentCancelled():
        await repo.failPayment(created.id, 'Payment cancelled');
        return const PaymentNotCompleted(
          ClothsyCopy.paymentCancelled,
          cancelledByCustomer: true,
        );
    }
  }

  Future<Order> cancelOrder(String orderId, String reason) async {
    final repo = ref.read(orderRepositoryProvider);
    final cancelled = await repo.cancelOrder(orderId, reason);
    state = state.map((o) => o.id == orderId ? cancelled : o).toList();
    return cancelled;
  }

  Future<Order> cancelSellerOrder(
    String orderId,
    String sellerOrderId,
    String reason,
  ) async {
    final repo = ref.read(orderRepositoryProvider);
    final updated = await repo.cancelSellerOrder(
      orderId,
      sellerOrderId,
      reason,
    );
    state = state.map((o) => o.id == orderId ? updated : o).toList();
    return updated;
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);

final orderDetailProvider = FutureProvider.family<Order?, String>((
  ref,
  id,
) async {
  final repo = ref.read(orderRepositoryProvider);
  return repo.getOrderById(id);
});
