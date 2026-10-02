import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'package:clothsy_core/features/orders/domain/order_splitter.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

CartLineItem line(
  String id, {
  required String sellerId,
  required String brand,
  required int price,
  int quantity = 1,
}) {
  final variant = ProductVariant(
    id: 'v_$id',
    title: 'M',
    size: 'M',
    colorName: 'Black',
    colorHex: '0xFF000000',
    price: price,
  );
  return CartLineItem(
    id: 'line_$id',
    quantity: quantity,
    variant: variant,
    product: Product(
      id: 'p_$id',
      handle: id,
      title: 'Product $id',
      sellerId: sellerId,
      brand: brand,
      description: '',
      price: price,
      images: const [],
      availableSizes: const ['M'],
      variants: [variant],
      category: 'Women',
    ),
  );
}

const address = Address(
  id: 'addr_1',
  name: 'Riya',
  phone: '+91 99999 00001',
  street: 'MG Road',
  city: 'Bengaluru',
  state: 'Karnataka',
  pinCode: '560001',
);

Order orderOf(
  List<SellerOrder> parts, {
  PaymentStatus paymentStatus = PaymentStatus.paid,
  PaymentMethod method = PaymentMethod.upi,
}) {
  return Order(
    id: 'o1',
    orderNumber: 'CLY-1',
    orderDate: DateTime(2026, 10, 2),
    sellerOrders: parts,
    shippingAddress: address,
    method: method,
    paymentMethod: method.label,
    paymentStatus: paymentStatus,
  );
}

SellerOrder part(String id, OrderStatus status, {int subtotal = 100000}) {
  return SellerOrder(
    id: id,
    reference: 'CLY-1-$id',
    sellerId: 'sel_$id',
    sellerName: 'Seller $id',
    items: const [],
    subtotal: subtotal,
    status: status,
  );
}

void main() {
  final blazer = line(
    'blazer',
    sellerId: 'sel_noor',
    brand: 'Noor Atelier',
    price: 799900,
  );
  final tee = line(
    'tee',
    sellerId: 'sel_rao',
    brand: 'Studio Rao',
    price: 99900,
  );
  final shirt = line(
    'shirt',
    sellerId: 'sel_rao',
    brand: 'Studio Rao',
    price: 49900,
    quantity: 2,
  );

  group('CartSummary (multi-seller bag)', () {
    test('groups by seller in the order sellers were first added', () {
      final cart = CartSummary(items: [blazer, tee, shirt]);
      final groups = cart.sellerGroups;
      expect(groups.map((g) => g.sellerId), ['sel_noor', 'sel_rao']);
      expect(groups[1].items.length, 2);
      expect(groups[1].itemCount, 3);
      expect(groups[1].subtotal, 99900 + 2 * 49900);
      expect(cart.shipmentCount, 2);
    });

    test('charges shipping per seller below the free-delivery threshold', () {
      final cart = CartSummary(items: [blazer, tee]);
      final noor = cart.sellerGroups[0];
      final rao = cart.sellerGroups[1];
      expect(noor.shippingFee, 0); // ₹7,999 ≥ ₹1,999
      expect(rao.shippingFee, CartSummary.standardShippingFee);
      expect(rao.amountToFreeShipping, 199900 - 99900);
      expect(cart.shippingFee, CartSummary.standardShippingFee);
      expect(cart.total, 799900 + 99900 + CartSummary.standardShippingFee);
    });

    test('an empty bag costs nothing', () {
      const cart = CartSummary();
      expect(cart.isEmpty, isTrue);
      expect(cart.shippingFee, 0);
      expect(cart.total, 0);
    });

    test('total never goes below zero', () {
      final cart = CartSummary(items: [tee], discountAmount: 9999999);
      expect(cart.total, 0);
    });
  });

  group('OrderSplitter', () {
    test('creates one seller order per seller with A/B references', () {
      final parts = OrderSplitter.split(
        orderId: 'ord_9',
        orderNumber: 'CLY-55555',
        items: [blazer, tee],
        discount: 0,
        initialStatus: OrderStatus.placed,
        placedAt: DateTime(2026, 10, 2),
      );
      expect(parts.map((p) => p.reference), ['CLY-55555-A', 'CLY-55555-B']);
      expect(parts.map((p) => p.id), ['ord_9_a', 'ord_9_b']);
      expect(parts.map((p) => p.sellerName), ['Noor Atelier', 'Studio Rao']);
      expect(parts[0].shippingFee, 0);
      expect(parts[1].shippingFee, CartSummary.standardShippingFee);
    });

    test('splits a coupon across sellers by subtotal, to the paisa', () {
      final rao = line(
        'rao',
        sellerId: 'sel_rao',
        brand: 'Studio Rao',
        price: 499900,
      );
      final parts = OrderSplitter.split(
        orderId: 'o',
        orderNumber: 'CLY-1',
        items: [blazer, rao],
        discount: 50000,
        initialStatus: OrderStatus.placed,
        placedAt: DateTime(2026, 10, 2),
      );
      expect(parts.map((p) => p.discountShare), [30770, 19230]);
      final order = orderOf(parts);
      expect(order.discount, 50000);
      expect(order.total, 799900 + 499900 - 50000);
    });

    test('caps the discount at the value of the goods', () {
      final parts = OrderSplitter.split(
        orderId: 'o',
        orderNumber: 'CLY-1',
        items: [tee],
        discount: 500000,
        initialStatus: OrderStatus.placed,
        placedAt: DateTime(2026, 10, 2),
      );
      expect(parts.single.discountShare, 99900);
      // The customer still pays for the shipment.
      expect(parts.single.total, CartSummary.standardShippingFee);
    });

    test('suffixes go A..Z then numbers', () {
      expect(OrderSplitter.suffix(0), 'A');
      expect(OrderSplitter.suffix(25), 'Z');
      expect(OrderSplitter.suffix(26), '27');
    });

    test('a prepaid order starts with nothing tracked yet', () {
      final parts = OrderSplitter.split(
        orderId: 'o',
        orderNumber: 'CLY-1',
        items: [tee],
        discount: 0,
        initialStatus: OrderStatus.pendingPayment,
        placedAt: DateTime(2026, 10, 2),
      );
      expect(parts.single.status, OrderStatus.pendingPayment);
      expect(parts.single.trackingSteps.any((s) => s.isCompleted), isFalse);
    });
  });

  group('TrackingStep.timeline', () {
    test('marks the steps up to the current status', () {
      final steps = TrackingStep.timeline(
        status: OrderStatus.shipped,
        sellerName: 'Noor Atelier',
        placedAt: DateTime(2026, 10, 2),
      );
      expect(steps.length, 5);
      expect(steps.where((s) => s.isCompleted).length, 3);
      expect(steps[2].isCurrent, isTrue);
      expect(steps[1].description, contains('Noor Atelier'));
    });

    test('delivered completes the whole timeline', () {
      final steps = TrackingStep.timeline(
        status: OrderStatus.delivered,
        sellerName: 'Studio Rao',
        placedAt: DateTime(2026, 10, 2),
      );
      expect(steps.every((s) => s.isCompleted), isTrue);
    });
  });

  group('Order status and refunds', () {
    test('overall status is the least advanced part still in play', () {
      final order = orderOf([
        part('a', OrderStatus.delivered),
        part('b', OrderStatus.shipped),
        part('c', OrderStatus.cancelled),
      ]);
      expect(order.status, OrderStatus.shipped);
    });

    test('delivered only once every shipment has arrived', () {
      expect(
        orderOf([
          part('a', OrderStatus.delivered),
          part('b', OrderStatus.delivered),
        ]).status,
        OrderStatus.delivered,
      );
    });

    test('falls back to cancelled or returned when nothing is in play', () {
      expect(
        orderOf([
          part('a', OrderStatus.cancelled),
          part('b', OrderStatus.cancelled),
        ]).status,
        OrderStatus.cancelled,
      );
      expect(
        orderOf([
          part('a', OrderStatus.cancelled),
          part('b', OrderStatus.returned),
        ]).status,
        OrderStatus.returned,
      );
    });

    test('only parts not yet shipped can be cancelled', () {
      expect(part('a', OrderStatus.packed).canBeCancelled, isTrue);
      expect(part('a', OrderStatus.shipped).canBeCancelled, isFalse);
      final order = orderOf([
        part('a', OrderStatus.shipped),
        part('b', OrderStatus.placed),
      ]);
      expect(order.canBeCancelled, isTrue);
    });

    test('refunds the cancelled parts of a prepaid order', () {
      final order = orderOf([
        part('a', OrderStatus.cancelled, subtotal: 120000),
        part('b', OrderStatus.placed, subtotal: 300000),
      ]);
      expect(order.refundAmount, 120000);
    });

    test('cash-on-delivery orders have nothing to refund', () {
      final order = orderOf(
        [part('a', OrderStatus.cancelled)],
        paymentStatus: PaymentStatus.cashOnDelivery,
        method: PaymentMethod.cashOnDelivery,
      );
      expect(order.refundAmount, 0);
    });

    test('totals are derived from the seller orders', () {
      final order = orderOf([
        const SellerOrder(
          id: 'a',
          reference: 'CLY-1-A',
          sellerId: 's1',
          sellerName: 'S1',
          items: [],
          subtotal: 100000,
          shippingFee: 15000,
          discountShare: 10000,
        ),
        const SellerOrder(
          id: 'b',
          reference: 'CLY-1-B',
          sellerId: 's2',
          sellerName: 'S2',
          items: [],
          subtotal: 250000,
          discountShare: 25000,
        ),
      ]);
      expect(order.subtotal, 350000);
      expect(order.shippingFee, 15000);
      expect(order.discount, 35000);
      expect(order.total, 330000);
      expect(order.sellerOrderById('b')?.total, 225000);
      expect(order.sellerOrderById('zz'), isNull);
    });
  });

  group('PaymentMethod', () {
    test('only cash on delivery is collected later', () {
      expect(PaymentMethod.upi.isPrepaid, isTrue);
      expect(PaymentMethod.card.isPrepaid, isTrue);
      expect(PaymentMethod.netBanking.isPrepaid, isTrue);
      expect(PaymentMethod.cashOnDelivery.isPrepaid, isFalse);
    });
  });
}
