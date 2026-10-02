import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'package:clothsy_core/features/orders/domain/repositories/order_repository.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';
import 'package:clothsy_shop/features/orders/data/repositories/mock_order_repository.dart';
import 'package:clothsy_shop/features/orders/presentation/providers/order_providers.dart';
import 'package:clothsy_shop/features/payments/data/mock_payment_gateway.dart';
import 'package:clothsy_shop/features/payments/presentation/providers/payment_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CartLineItem line(String id, String sellerId, String brand, int price) {
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

/// Two brands in one bag: ₹7,999 from Noor Atelier, ₹999 from Studio Rao.
final twoBrandBag = CartSummary(
  items: [
    line('blazer', 'sel_noor', 'Noor Atelier', 799900),
    line('tee', 'sel_rao', 'Studio Rao', 99900),
  ],
);

void main() {
  late MockOrderRepository repo;
  late MockPaymentGateway gateway;
  late ProviderContainer container;

  ProviderContainer containerWith(MockPaymentGateway g) {
    final c = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(repo),
        paymentGatewayProvider.overrideWithValue(g),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<PlaceOrderResult> place(
    PaymentMethod method, {
    CartSummary? cart,
  }) async {
    // Let the seeded orders load first so they don't race the new one.
    container.read(ordersProvider);
    await repo.getOrders();
    return container
        .read(ordersProvider.notifier)
        .placeOrder(
          cart: cart ?? twoBrandBag,
          address: address,
          method: method,
          customerName: address.name,
          customerPhone: address.phone,
          upiApp: 'Google Pay',
        );
  }

  setUp(() {
    repo = MockOrderRepository();
    gateway = MockPaymentGateway(delay: Duration.zero);
    container = containerWith(gateway);
  });

  group('MockPaymentGateway', () {
    test(
      'succeeds by default and records what it was asked to collect',
      () async {
        const request = PaymentRequest(
          orderId: 'ord_1',
          orderNumber: 'CLY-1',
          amount: 449900,
          method: PaymentMethod.upi,
          customerName: 'Riya',
          customerPhone: '+91 99999 00001',
        );
        final result = await gateway.pay(request);
        expect(result, isA<PaymentSuccess>());
        expect((result as PaymentSuccess).paymentRef, 'pay_mock_ord_1');
        expect(gateway.requests.single.amount, 449900);
      },
    );

    test('a responder can simulate failure or cancellation', () async {
      final failing = MockPaymentGateway(
        delay: Duration.zero,
        responder: (_) => const PaymentFailure('Declined'),
      );
      const request = PaymentRequest(
        orderId: 'o',
        orderNumber: 'n',
        amount: 1,
        method: PaymentMethod.card,
        customerName: 'a',
        customerPhone: 'b',
      );
      expect(await failing.pay(request), isA<PaymentFailure>());
    });
  });

  group('OrdersNotifier.placeOrder', () {
    test('prepaid: create → pay → confirm, split into seller orders', () async {
      final result = await place(PaymentMethod.upi);

      expect(result, isA<OrderPlaced>());
      final order = (result as OrderPlaced).order;
      expect(order.paymentStatus, PaymentStatus.paid);
      expect(order.paymentMethod, 'UPI (Google Pay)');
      expect(order.sellerOrders.length, 2);
      expect(
        order.sellerOrders.every((so) => so.status == OrderStatus.placed),
        isTrue,
      );
      // The gateway charged exactly what the repository computed.
      expect(gateway.requests.single.amount, order.total);
      expect(order.total, 799900 + 99900 + CartSummary.standardShippingFee);
      expect(container.read(ordersProvider).first.id, order.id);
    });

    test('cash on delivery is placed without touching the gateway', () async {
      final result = await place(PaymentMethod.cashOnDelivery);

      final order = (result as OrderPlaced).order;
      expect(order.paymentStatus, PaymentStatus.cashOnDelivery);
      expect(order.status, OrderStatus.placed);
      expect(gateway.requests, isEmpty);
    });

    test('a failed payment is not charged and the order is hidden', () async {
      gateway = MockPaymentGateway(
        delay: Duration.zero,
        responder: (_) => const PaymentFailure('Bank declined'),
      );
      container = containerWith(gateway);

      final result = await place(PaymentMethod.card);

      expect(result, isA<PaymentNotCompleted>());
      result as PaymentNotCompleted;
      expect(result.message, ClothsyCopy.paymentFailed);
      expect(result.cancelledByCustomer, isFalse);

      final stored = await repo.getOrders();
      final failed = stored.firstWhere(
        (o) => o.paymentStatus == PaymentStatus.failed,
      );
      expect(failed.status, OrderStatus.cancelled);
      expect(
        container.read(ordersProvider).any((o) => o.id == failed.id),
        isFalse,
      );
    });

    test('closing the payment sheet keeps the bag for a retry', () async {
      gateway = MockPaymentGateway(
        delay: Duration.zero,
        responder: (_) => const PaymentCancelled(),
      );
      container = containerWith(gateway);

      final result = await place(PaymentMethod.upi);

      result as PaymentNotCompleted;
      expect(result.cancelledByCustomer, isTrue);
      expect(result.message, ClothsyCopy.paymentCancelled);
    });

    test('an empty bag is rejected before any payment', () async {
      final result = await place(PaymentMethod.upi, cart: const CartSummary());
      expect(result, isA<OrderRejected>());
      expect(gateway.requests, isEmpty);
    });
  });

  group('Order rules shared with the backend', () {
    Future<Order> create(
      List<CartLineItem> items, {
      String? key,
      int? expectedTotal,
      PaymentMethod method = PaymentMethod.cashOnDelivery,
    }) {
      return repo.createOrder(
        items: items,
        address: address,
        method: method,
        paymentLabel: method.label,
        discount: 0,
        idempotencyKey: key,
        expectedTotal: expectedTotal,
      );
    }

    test('the same idempotency key returns the same order', () async {
      final first = await create(twoBrandBag.items, key: 'key-1');
      final retry = await create(twoBrandBag.items, key: 'key-1');
      expect(retry.id, first.id);
      final other = await create(twoBrandBag.items, key: 'key-2');
      expect(other.id, isNot(first.id));
    });

    test('a changed total is refused before anything is held', () async {
      await expectLater(
        create(twoBrandBag.items, expectedTotal: 1),
        throwsA(
          isA<OrderException>().having((e) => e.code, 'code', 'PRICE_CHANGED'),
        ),
      );
    });

    test('stock is held per order and released on cancellation', () async {
      // Mock variants have 10 units: 6 + 6 cannot both be held.
      final six = line(
        'tee',
        'sel_rao',
        'Studio Rao',
        99900,
      ).copyWith(quantity: 6);
      final first = await create([six]);
      await expectLater(
        create([six]),
        throwsA(
          isA<OrderException>().having((e) => e.code, 'code', 'OUT_OF_STOCK'),
        ),
      );

      await repo.cancelOrder(first.id, 'Changed my mind');
      final again = await create([six]);
      expect(again.status, OrderStatus.placed);
    });

    test('a failed payment gives its stock back', () async {
      final six = line(
        'tee',
        'sel_rao',
        'Studio Rao',
        99900,
      ).copyWith(quantity: 6);
      final pending = await create([six], method: PaymentMethod.upi);
      expect(pending.paymentIntent?.gatewayOrderId, startsWith('order_mock_'));
      await repo.failPayment(pending.id, 'Declined');
      expect((await create([six])).status, OrderStatus.placed);
    });
  });

  group('Cancelling part of an order', () {
    test('refunds one seller order and leaves the other shipping', () async {
      final placed = (await place(PaymentMethod.upi)) as OrderPlaced;
      final order = placed.order;
      final noorPart = order.sellerOrders.first;

      final updated = await container
          .read(ordersProvider.notifier)
          .cancelSellerOrder(order.id, noorPart.id, 'Changed my mind');

      expect(
        updated.sellerOrderById(noorPart.id)!.status,
        OrderStatus.cancelled,
      );
      expect(updated.sellerOrders.last.status, OrderStatus.placed);
      expect(updated.paymentStatus, PaymentStatus.paid);
      expect(updated.refundAmount, noorPart.total);
      expect(updated.status, OrderStatus.placed);

      final all = await container
          .read(ordersProvider.notifier)
          .cancelSellerOrder(
            order.id,
            order.sellerOrders.last.id,
            'Not needed',
          );
      expect(all.paymentStatus, PaymentStatus.refunded);
      expect(all.status, OrderStatus.cancelled);
      expect(all.refundAmount, order.total);
    });

    test('confirming the same payment twice changes nothing', () async {
      final placed = (await place(PaymentMethod.upi)) as OrderPlaced;
      final again = await repo.confirmPayment(
        placed.order.id,
        paymentRef: 'pay_mock_dup',
      );
      expect(again.paymentStatus, PaymentStatus.paid);
      expect(again.sellerOrders.length, placed.order.sellerOrders.length);
    });

    test('a late failure report never undoes a confirmed payment', () async {
      final placed = (await place(PaymentMethod.upi)) as OrderPlaced;
      final after = await repo.failPayment(placed.order.id, 'Timeout');
      expect(after.paymentStatus, PaymentStatus.paid);
    });
  });
}
