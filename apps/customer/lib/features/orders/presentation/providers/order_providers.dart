import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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

/// How long to keep checking for a payment the gateway approved but our
/// confirmation call could not record — the payment webhook usually lands
/// within seconds. Overridden to zero in tests.
final paymentConfirmationGraceProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 20),
);

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

  /// Why, e.g. `OUT_OF_STOCK` or `PRICE_CHANGED`.
  final String? code;
  const OrderRejected(this.message, {this.code});
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
        couponCode: cart.couponCode,
        // One key per attempt: a retried request returns the same order.
        idempotencyKey: const Uuid().v4(),
        expectedTotal: cart.total,
      );
    } on OrderException catch (e) {
      return OrderRejected(e.message, code: e.code);
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
        intent: created.paymentIntent,
      ),
    );

    switch (result) {
      case PaymentSuccess(:final paymentRef, :final signature):
        Order? confirmed;
        try {
          confirmed = await repo.confirmPayment(
            created.id,
            paymentRef: paymentRef,
            signature: signature,
            gatewayOrderId: created.paymentIntent?.gatewayOrderId,
          );
        } on OrderException {
          // The gateway said yes but we could not confirm it. Never claim the
          // order is paid: wait for the payment webhook, and if it does not
          // arrive the server refunds any amount that was debited.
          confirmed = await _awaitWebhookConfirmation(created.id);
        }
        if (confirmed == null) {
          return const PaymentNotCompleted(ClothsyCopy.paymentConfirming);
        }
        if (ref.mounted) state = [confirmed, ...state];
        return OrderPlaced(confirmed);
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

  /// Polls the order for up to [paymentConfirmationGraceProvider] until the
  /// payment webhook marks it paid. Returns null if it never does.
  Future<Order?> _awaitWebhookConfirmation(String orderId) async {
    final repo = ref.read(orderRepositoryProvider);
    final deadline = DateTime.now().add(
      ref.read(paymentConfirmationGraceProvider),
    );
    while (true) {
      final order = await repo.getOrderById(orderId);
      if (order?.paymentStatus == PaymentStatus.paid) return order;
      if (!DateTime.now().isBefore(deadline) || !ref.mounted) return null;
      await Future.delayed(const Duration(seconds: 2));
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
