import 'dart:math';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'package:clothsy_core/features/orders/domain/order_splitter.dart';
import 'package:clothsy_core/features/orders/domain/repositories/order_repository.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';

/// In-memory orders for the mock flavor and tests. Mirrors what the backend
/// does: split into seller orders, hold payment until confirmed, and refund
/// cancelled parts.
class MockOrderRepository implements OrderRepository {
  static const _sampleAddress = Address(
    id: 'addr_sample',
    name: 'Aastha Sudan',
    phone: '+91 98765 43210',
    street: 'Gulmohar Avenue, Vasant Vihar',
    apartment: 'Villa 14',
    city: 'New Delhi',
    state: 'Delhi',
    pinCode: '110057',
    isDefault: true,
  );

  late final List<Order> _orders = _seedOrders();

  /// Orders already placed for an idempotency key, so a retried checkout
  /// returns the same order instead of placing a second one.
  final Map<String, String> _orderIdByIdempotencyKey = {};

  /// Units held by orders that are placed or awaiting payment, per variant.
  final Map<String, int> _held = {};

  static CartLineItem _item({
    required String id,
    required String productId,
    required String title,
    required String sellerId,
    required String brand,
    required int price,
    required String image,
    required String variantId,
    required String variantTitle,
    required String size,
    required String colorName,
    int quantity = 1,
  }) {
    return CartLineItem(
      id: id,
      product: Product(
        id: productId,
        handle: productId,
        title: title,
        sellerId: sellerId,
        brand: brand,
        description: title,
        price: price,
        images: [image],
        availableSizes: [size],
        variants: const [],
        category: 'Women',
      ),
      variant: ProductVariant(
        id: variantId,
        title: variantTitle,
        size: size,
        colorName: colorName,
        colorHex: '0xFFD9CCA8',
        price: price,
      ),
      quantity: quantity,
    );
  }

  /// Splits [items] into seller orders, then overrides each seller order's
  /// status so the sample data shows different shipments at different stages.
  static Order _seed({
    required String id,
    required String orderNumber,
    required Duration age,
    required PaymentMethod method,
    required String paymentLabel,
    required List<CartLineItem> items,
    required int discount,
    required List<OrderStatus> statuses,
  }) {
    final placedAt = DateTime.now().subtract(age);
    final split = OrderSplitter.split(
      orderId: id,
      orderNumber: orderNumber,
      items: items,
      discount: discount,
      initialStatus: OrderStatus.placed,
      placedAt: placedAt,
    );
    return Order(
      id: id,
      orderNumber: orderNumber,
      orderDate: placedAt,
      shippingAddress: _sampleAddress,
      method: method,
      paymentMethod: paymentLabel,
      paymentStatus: PaymentStatus.paid,
      sellerOrders: [
        for (var i = 0; i < split.length; i++)
          split[i].copyWith(
            status: statuses[i],
            trackingSteps: TrackingStep.timeline(
              status: statuses[i],
              sellerName: split[i].sellerName,
              placedAt: placedAt,
            ),
          ),
      ],
    );
  }

  static List<Order> _seedOrders() {
    const blazer =
        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=900&auto=format&fit=crop&q=80';
    const linen =
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=900&auto=format&fit=crop&q=80';
    const dress =
        'https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=900&auto=format&fit=crop&q=80';
    const shirt =
        'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=900&auto=format&fit=crop&q=80';

    return [
      // One checkout, two sellers shipping separately.
      _seed(
        id: 'ord_103',
        orderNumber: 'CLY-91377',
        age: const Duration(days: 1),
        method: PaymentMethod.upi,
        paymentLabel: 'UPI (Google Pay)',
        discount: 50000,
        statuses: const [OrderStatus.packed, OrderStatus.placed],
        items: [
          _item(
            id: 'item_ord_3a',
            productId: 'p_lavender_blazer',
            title: 'Lavender Blazer',
            sellerId: 'sel_noor',
            brand: 'Noor Atelier',
            price: 799900,
            image: blazer,
            variantId: 'v_blazer_lavender',
            variantTitle: 'Soft Lavender / M',
            size: 'M',
            colorName: 'Soft Lavender',
          ),
          _item(
            id: 'item_ord_3b',
            productId: 'p_minimal_overshirt',
            title: 'Minimal Overshirt',
            sellerId: 'sel_rao',
            brand: 'Studio Rao',
            price: 499900,
            image: shirt,
            variantId: 'v_overshirt_sand',
            variantTitle: 'Khaki Sand / M',
            size: 'M',
            colorName: 'Khaki Sand',
          ),
        ],
      ),
      _seed(
        id: 'ord_101',
        orderNumber: 'CLY-84920',
        age: const Duration(days: 2),
        method: PaymentMethod.upi,
        paymentLabel: 'UPI (Google Pay)',
        discount: 65000,
        statuses: const [OrderStatus.shipped],
        items: [
          _item(
            id: 'item_ord_1',
            productId: 'p2',
            title: 'Linen Tailored Blazer',
            sellerId: 'sel_rao',
            brand: 'Studio Rao',
            price: 649900,
            image: linen,
            variantId: 'v2_sand',
            variantTitle: 'Warm Sand / M',
            size: 'M',
            colorName: 'Warm Sand',
          ),
        ],
      ),
      _seed(
        id: 'ord_102',
        orderNumber: 'CLY-72149',
        age: const Duration(days: 14),
        method: PaymentMethod.card,
        paymentLabel: 'Credit Card (HDFC Visa)',
        discount: 0,
        statuses: const [OrderStatus.delivered],
        items: [
          _item(
            id: 'item_ord_2',
            productId: 'p1',
            title: 'Silk Satin Maxi Dress',
            sellerId: 'sel_noor',
            brand: 'Noor Atelier',
            price: 499900,
            image: dress,
            variantId: 'v1_plum',
            variantTitle: 'Plum Noir / M',
            size: 'M',
            colorName: 'Plum Noir',
          ),
        ],
      ),
    ];
  }

  int _indexOf(String id) =>
      _orders.indexWhere((o) => o.id == id || o.orderNumber == id);

  Order _require(String id) {
    final index = _indexOf(id);
    if (index < 0) throw const OrderException('Order not found');
    return _orders[index];
  }

  void _store(Order order) => _orders[_indexOf(order.id)] = order;

  @override
  Future<List<Order>> getOrders() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_orders);
  }

  @override
  Future<Order?> getOrderById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _indexOf(id);
    return index < 0 ? null : _orders[index];
  }

  @override
  Future<Order> createOrder({
    required List<CartLineItem> items,
    required Address address,
    required PaymentMethod method,
    required String paymentLabel,
    required int discount,
    String? couponCode,
    String? idempotencyKey,
    int? expectedTotal,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final replayId = _orderIdByIdempotencyKey[idempotencyKey];
    if (replayId != null) return _require(replayId);
    if (items.isEmpty) {
      throw const OrderException('Your bag is empty.', code: 'EMPTY_BAG');
    }

    // The whole bag must be in stock, or nothing is held.
    final wanted = <String, int>{};
    for (final item in items) {
      wanted[item.variant.id] = (wanted[item.variant.id] ?? 0) + item.quantity;
    }
    for (final item in items) {
      final available =
          item.variant.inventoryQuantity - (_held[item.variant.id] ?? 0);
      if (wanted[item.variant.id]! > available) {
        throw OrderException(
          '${item.product.title} in size ${item.variant.size} just sold out. '
          'Remove it or pick another size.',
          code: 'OUT_OF_STOCK',
        );
      }
    }

    final id = 'ord_${DateTime.now().microsecondsSinceEpoch}';
    final orderNumber = 'CLY-${10000 + Random().nextInt(90000)}';
    final prepaid = method.isPrepaid;
    final now = DateTime.now();

    final order = Order(
      id: id,
      orderNumber: orderNumber,
      orderDate: now,
      shippingAddress: address,
      method: method,
      paymentMethod: paymentLabel,
      paymentStatus: prepaid
          ? PaymentStatus.pending
          : PaymentStatus.cashOnDelivery,
      paymentIntent: prepaid
          ? PaymentIntent(
              provider: 'mock',
              keyId: 'rzp_test_mock',
              gatewayOrderId: 'order_mock_$id',
            )
          : null,
      sellerOrders: OrderSplitter.split(
        orderId: id,
        orderNumber: orderNumber,
        items: items,
        discount: discount,
        initialStatus: prepaid
            ? OrderStatus.pendingPayment
            : OrderStatus.placed,
        placedAt: now,
      ),
    );
    if (expectedTotal != null && order.total != expectedTotal) {
      throw const OrderException(
        'Prices in your bag changed. Review your bag and place the order '
        'again.',
        code: 'PRICE_CHANGED',
      );
    }

    wanted.forEach((variantId, quantity) {
      _held[variantId] = (_held[variantId] ?? 0) + quantity;
    });
    if (idempotencyKey != null) _orderIdByIdempotencyKey[idempotencyKey] = id;
    _orders.insert(0, order);
    return order;
  }

  /// Gives a cancelled or unpaid seller order's units back to stock.
  void _release(SellerOrder so) {
    for (final item in so.items) {
      final held = (_held[item.variant.id] ?? 0) - item.quantity;
      if (held > 0) {
        _held[item.variant.id] = held;
      } else {
        _held.remove(item.variant.id);
      }
    }
  }

  @override
  Future<Order> confirmPayment(
    String orderId, {
    required String paymentRef,
    String? signature,
    String? gatewayOrderId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final order = _require(orderId);

    // Idempotent: a repeated confirmation (retry, duplicate webhook) is a
    // no-op instead of a second state change.
    if (order.paymentStatus == PaymentStatus.paid) return order;
    if (order.paymentStatus != PaymentStatus.pending) {
      throw const OrderException(
        'This order is no longer waiting for payment.',
        code: 'NOT_PENDING',
      );
    }

    final confirmed = order.copyWith(
      paymentStatus: PaymentStatus.paid,
      sellerOrders: [
        for (final so in order.sellerOrders)
          so.copyWith(
            status: OrderStatus.placed,
            trackingSteps: TrackingStep.timeline(
              status: OrderStatus.placed,
              sellerName: so.sellerName,
              placedAt: DateTime.now(),
            ),
          ),
      ],
    );
    _store(confirmed);
    return confirmed;
  }

  @override
  Future<Order> failPayment(String orderId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final order = _require(orderId);

    // A late "failed" report must never undo a payment that already succeeded.
    if (order.paymentStatus == PaymentStatus.paid ||
        order.paymentStatus == PaymentStatus.failed) {
      return order;
    }

    order.sellerOrders.forEach(_release);
    final failed = order.copyWith(
      paymentStatus: PaymentStatus.failed,
      sellerOrders: [
        for (final so in order.sellerOrders)
          so.copyWith(
            status: OrderStatus.cancelled,
            trackingSteps: [
              TrackingStep(
                title: 'Payment failed',
                description: reason,
                date: DateTime.now(),
                isCompleted: true,
                isCurrent: true,
              ),
            ],
          ),
      ],
    );
    _store(failed);
    return failed;
  }

  SellerOrder _cancelled(Order order, SellerOrder so, String reason) {
    _release(so);
    final String note;
    if (order.paymentStatus == PaymentStatus.paid) {
      note =
          'Reason: $reason. '
          '${ClothsyCopy.refundStarted(amount: CurrencyFormatter.format(so.total), destination: order.method.refundDestination)}';
    } else {
      note = 'Reason: $reason. ${ClothsyCopy.noPaymentTaken}';
    }
    return so.copyWith(
      status: OrderStatus.cancelled,
      trackingSteps: [
        ...so.trackingSteps.map(
          (s) => TrackingStep(
            title: s.title,
            description: s.description,
            date: s.date,
            isCompleted: s.isCompleted,
          ),
        ),
        TrackingStep(
          title: 'Cancelled',
          description: note,
          date: DateTime.now(),
          isCompleted: true,
          isCurrent: true,
        ),
      ],
    );
  }

  Order _afterCancelling(Order order, List<SellerOrder> updated) {
    final allCancelled = updated.every(
      (so) => so.status == OrderStatus.cancelled,
    );
    return order.copyWith(
      sellerOrders: updated,
      paymentStatus: allCancelled && order.paymentStatus == PaymentStatus.paid
          ? PaymentStatus.refunded
          : order.paymentStatus,
    );
  }

  @override
  Future<Order> cancelOrder(String orderId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final order = _require(orderId);
    if (!order.canBeCancelled) {
      throw const OrderException(
        'This order has already shipped, so it can no longer be cancelled.',
        code: 'NOT_CANCELLABLE',
      );
    }
    final updated = [
      for (final so in order.sellerOrders)
        so.canBeCancelled ? _cancelled(order, so, reason) : so,
    ];
    final result = _afterCancelling(order, updated);
    _store(result);
    return result;
  }

  @override
  Future<Order> cancelSellerOrder(
    String orderId,
    String sellerOrderId,
    String reason,
  ) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final order = _require(orderId);
    final target = order.sellerOrderById(sellerOrderId);
    if (target == null) throw const OrderException('Order not found');
    if (!target.canBeCancelled) {
      throw OrderException(
        '${target.sellerName} has already shipped this part of your order, '
        'so it can no longer be cancelled.',
        code: 'NOT_CANCELLABLE',
      );
    }
    final updated = [
      for (final so in order.sellerOrders)
        so.id == sellerOrderId ? _cancelled(order, so, reason) : so,
    ];
    final result = _afterCancelling(order, updated);
    _store(result);
    return result;
  }
}
