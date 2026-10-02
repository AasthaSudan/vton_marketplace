import 'package:clothsy_core/data/mappers/account_mappers.dart';
import 'package:clothsy_core/data/mappers/catalog_mappers.dart';
import 'package:clothsy_core/data/mappers/order_mappers.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

// Shapes as PostgREST returns them for the Clothsy schema.
Map<String, dynamic> productRow() => {
  'id': 'a1b2c3d4-0000-0000-0000-000000000001',
  'seller_id': 's-1',
  'handle': 'lavender-blazer',
  'title': 'Lavender Blazer',
  'description': 'Tailored.',
  'category': 'Women',
  'tags': ['Blazer'],
  'images': ['https://example.com/a.jpg'],
  'rating': 4.8,
  'review_count': 120,
  'is_tryon_eligible': true,
  'is_featured': true,
  'is_new': false,
  'min_price': 799900,
  'min_compare_at_price': 999900,
  'seller': {'id': 's-1', 'name': 'Noor Atelier', 'handle': 'noor-atelier'},
  'variants': [
    {
      'id': 'v-l',
      'title': 'Charcoal / L',
      'size': 'L',
      'size_rank': 4,
      'color_name': 'Charcoal',
      'color_hex': '#363636',
      'price': 799900,
      'compare_at_price': 999900,
      'stock': 0,
      'image_url': null,
      'position': 2,
      'is_active': true,
    },
    {
      'id': 'v-m',
      'title': 'Soft Lavender / M',
      'size': 'M',
      'size_rank': 3,
      'color_name': 'Soft Lavender',
      'color_hex': '#b9a6e0',
      'price': 799900,
      'compare_at_price': 999900,
      'stock': 10,
      'image_url': 'https://example.com/m.jpg',
      'position': 0,
      'is_active': true,
    },
    {
      'id': 'v-old',
      'title': 'Old',
      'size': 'S',
      'size_rank': 2,
      'color_name': 'Old',
      'color_hex': '#000000',
      'price': 1,
      'stock': 5,
      'position': 1,
      'is_active': false,
    },
  ],
};

Map<String, dynamic> orderRow({String paymentStatus = 'partially_refunded'}) =>
    {
      'id': 'o-1',
      'order_number': 'CLY-48211903',
      'created_at': '2026-10-02T10:00:00Z',
      'payment_method': 'upi',
      'payment_label': 'UPI (Google Pay)',
      'payment_status': paymentStatus,
      'shipping_address': {
        'label': 'Home',
        'name': 'Riya',
        'phone': '+919999900001',
        'line1': '1 MG Road',
        'line2': 'Flat 4',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'pin_code': '560001',
      },
      'seller_orders': [
        {
          'id': 'so-b',
          'position': 1,
          'reference': 'CLY-48211903-B',
          'seller_id': 's-2',
          'seller_name': 'Test Label',
          'status': 'cancelled',
          'subtotal': 99900,
          'shipping_fee': 15000,
          'discount_share': 0,
          'total': 114900,
          'cancel_reason': 'Changed my mind',
          'cancelled_at': '2026-10-02T11:00:00Z',
          'order_items': [
            {
              'id': 'i-2',
              'product_id': 'p-2',
              'variant_id': 'v-2',
              'seller_id': 's-2',
              'title': 'Tee',
              'variant_title': 'White / M',
              'size': 'M',
              'color_name': 'White',
              'color_hex': '#FFFFFF',
              'image_url': null,
              'unit_price': 99900,
              'compare_at_price': null,
              'quantity': 1,
              'position': 1,
            },
          ],
        },
        {
          'id': 'so-a',
          'position': 0,
          'reference': 'CLY-48211903-A',
          'seller_id': 's-1',
          'seller_name': 'Noor Atelier',
          'status': 'shipped',
          'subtotal': 799900,
          'shipping_fee': 0,
          'discount_share': 0,
          'total': 799900,
          'order_items': [
            {
              'id': 'i-1',
              'product_id': 'p-1',
              'variant_id': 'v-1',
              'seller_id': 's-1',
              'title': 'Lavender Blazer',
              'variant_title': 'Soft Lavender / M',
              'size': 'M',
              'color_name': 'Soft Lavender',
              'color_hex': '#B9A6E0',
              'image_url': 'https://example.com/m.jpg',
              'unit_price': 799900,
              'compare_at_price': 999900,
              'quantity': 1,
              'position': 0,
            },
          ],
        },
      ],
      'refunds': [
        {'amount': 114900, 'status': 'pending', 'seller_order_id': 'so-b'},
      ],
      'payments': [
        {
          'provider': 'razorpay',
          'provider_order_id': 'order_1',
          'state': 'captured',
        },
      ],
    };

void main() {
  group('CatalogMappers.product', () {
    final product = CatalogMappers.product(productRow());

    test('brand, price and compare-at come from the row', () {
      expect(product.brand, 'Noor Atelier');
      expect(product.price, 799900);
      expect(product.originalPrice, 999900);
      expect(product.discountPercentage, 20);
    });

    test('only active variants, in position order, with app colour format', () {
      expect(product.variants.map((v) => v.id), ['v-m', 'v-l']);
      expect(product.variants.first.colorHex, '0xFFB9A6E0');
      expect(product.variants.last.isAvailable, isFalse);
    });

    test('sizes in size order', () {
      expect(product.availableSizes, ['M', 'L']);
    });
  });

  group('OrderMappers.order', () {
    final order = OrderMappers.order(orderRow());

    test('seller orders keep their bag order and totals', () {
      expect(order.sellerOrders.map((so) => so.reference), [
        'CLY-48211903-A',
        'CLY-48211903-B',
      ]);
      expect(order.total, 914800);
      expect(order.method, PaymentMethod.upi);
    });

    test('a part-refunded order is a paid order with a refund', () {
      expect(order.paymentStatus, PaymentStatus.paid);
      expect(order.refundAmount, 114900);
      expect(order.status, OrderStatus.shipped);
    });

    test('a cancelled part explains its refund on the timeline', () {
      final cancelled = order.sellerOrders.last;
      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.trackingSteps.last.title, 'Cancelled');
      expect(
        cancelled.trackingSteps.last.description,
        contains('Refund of ₹1,149 started'),
      );
      expect(cancelled.trackingSteps.last.description, contains('UPI'));
    });

    test('items are rebuilt from their snapshot', () {
      final item = order.sellerOrders.first.items.single;
      expect(item.product.title, 'Lavender Blazer');
      expect(item.variant.price, 799900);
      expect(item.product.brand, 'Noor Atelier');
    });

    test('the delivery address is the snapshot', () {
      expect(order.shippingAddress.street, '1 MG Road');
      expect(order.shippingAddress.apartment, 'Flat 4');
      expect(order.shippingAddress.pinCode, '560001');
    });

    test('a pending order carries its payment intent', () {
      final row = orderRow(paymentStatus: 'pending');
      row['payments'] = [
        {
          'provider': 'mock',
          'provider_order_id': 'order_mock_1',
          'state': 'created',
        },
      ];
      final pending = OrderMappers.order(row);
      expect(pending.paymentIntent?.gatewayOrderId, 'order_mock_1');
    });

    test('payment and status codes map both ways', () {
      for (final m in PaymentMethod.values) {
        expect(
          OrderMappers.paymentMethod(OrderMappers.paymentMethodCode(m)),
          m,
        );
      }
      expect(
        OrderMappers.status('out_for_delivery'),
        OrderStatus.outForDelivery,
      );
      expect(OrderMappers.paymentStatus('cod'), PaymentStatus.cashOnDelivery);
    });
  });

  group('AccountMappers', () {
    test('Indian phone numbers become E.164', () {
      expect(AccountMappers.e164India('98765 43210'), '+919876543210');
      expect(AccountMappers.e164India('+91 98765 43210'), '+919876543210');
      expect(AccountMappers.e164India('919876543210'), '+919876543210');
    });

    test('a shopper keeps their sign-in phone and an empty name', () {
      final user = AccountMappers.user(
        id: 'u-1',
        // What the new-user trigger stores: Auth's digits-only phone.
        profile: {'full_name': '', 'phone': '919999900001'},
        phone: '+919999900001',
      );
      expect(user.phone, '+919999900001');
      expect(user.name, '');
      expect(user.memberTier, 'Clothsy Member');
    });

    test('addresses round-trip through rows', () {
      final address = AccountMappers.address({
        'id': 'a-1',
        'name': 'Riya',
        'phone': '+919999900001',
        'line1': '1 MG Road',
        'line2': '',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'pin_code': '560001',
        'is_default': true,
        'label': 'Home',
      });
      final row = AccountMappers.addressRow(address);
      expect(row['line1'], '1 MG Road');
      expect(row['pin_code'], '560001');
      expect(row['is_default'], isTrue);
      expect(row.containsKey('id'), isFalse);
    });

    test('PIN checks map from the database function', () {
      final pin = AccountMappers.pin({
        'pin_code': '700001',
        'serviceable': true,
        'cod_available': false,
        'eta_days': 3,
        'city': 'Kolkata',
        'state': 'West Bengal',
      });
      expect(pin.serviceable, isTrue);
      expect(pin.codAvailable, isFalse);
      expect(pin.etaDays, 3);
    });
  });
}
