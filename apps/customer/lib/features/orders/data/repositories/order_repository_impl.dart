import 'dart:math';
import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'package:clothsy_core/features/orders/domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final List<Order> _orders = [
    Order(
      id: 'ord_101',
      orderNumber: 'CLY-84920',
      orderDate: DateTime.now().subtract(const Duration(days: 2)),
      shippingAddress: const Address(
        id: 'addr_sample',
        name: 'Aastha Sudan',
        phone: '+91 98765 43210',
        street: 'Gulmohar Avenue, Vasant Vihar',
        apartment: 'Villa 14',
        city: 'New Delhi',
        state: 'Delhi',
        pinCode: '110057',
        isDefault: true,
      ),
      deliveryMethod: 'Complimentary Express (2-4 Days)',
      paymentMethod: 'UPI (Google Pay)',
      paymentStatus: 'Paid',
      subtotal: 649900,
      discount: 65000,
      shippingFee: 0,
      total: 584900,
      status: OrderStatus.shipped,
      items: const [
        CartLineItem(
          id: 'item_ord_1',
          product: Product(
            id: 'p2',
            handle: 'linen-tailored-blazer',
            title: 'Linen Tailored Blazer',
            brand: 'Clothsy Studio',
            description: 'Structured Normandy flax linen blazer.',
            price: 649900,
            images: [
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=900&auto=format&fit=crop&q=80',
            ],
            availableSizes: ['S', 'M'],
            variants: [],
            category: 'Outerwear',
          ),
          variant: ProductVariant(
            id: 'v2_sand',
            title: 'Warm Sand / M',
            size: 'M',
            colorName: 'Warm Sand',
            colorHex: '0xFFD9CCA8',
            price: 649900,
          ),
          quantity: 1,
        ),
      ],
      trackingSteps: [
        TrackingStep(
          title: 'Order Placed',
          description: 'Payment confirmed & order received by Clothsy Atelier.',
          date: DateTime.now().subtract(const Duration(days: 2)),
          isCompleted: true,
        ),
        TrackingStep(
          title: 'Packed at Atelier',
          description:
              'Hand-inspected, steam-pressed, and packaged in signature luxury box.',
          date: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
          isCompleted: true,
        ),
        TrackingStep(
          title: 'Shipped with BlueDart Apex',
          description:
              'Package handed over to express transit (AWB #84920412).',
          date: DateTime.now().subtract(const Duration(hours: 12)),
          isCompleted: true,
          isCurrent: true,
        ),
        const TrackingStep(
          title: 'Out for Delivery',
          description: 'Courier agent will arrive at your doorstep.',
          isCompleted: false,
        ),
        const TrackingStep(
          title: 'Delivered',
          description: 'Package delivered.',
          isCompleted: false,
        ),
      ],
    ),
    Order(
      id: 'ord_102',
      orderNumber: 'CLY-72149',
      orderDate: DateTime.now().subtract(const Duration(days: 14)),
      shippingAddress: const Address(
        id: 'addr_sample',
        name: 'Aastha Sudan',
        phone: '+91 98765 43210',
        street: 'Gulmohar Avenue, Vasant Vihar',
        apartment: 'Villa 14',
        city: 'New Delhi',
        state: 'Delhi',
        pinCode: '110057',
        isDefault: true,
      ),
      deliveryMethod: 'Complimentary Express',
      paymentMethod: 'Credit Card (HDFC Visa)',
      paymentStatus: 'Paid',
      subtotal: 499900,
      discount: 0,
      shippingFee: 0,
      total: 499900,
      status: OrderStatus.delivered,
      items: const [
        CartLineItem(
          id: 'item_ord_2',
          product: Product(
            id: 'p1',
            handle: 'silk-satin-maxi-dress',
            title: 'Silk Satin Maxi Dress',
            brand: 'Clothsy Atelier',
            description: '22-momme Mulberry silk satin cowl neck maxi dress.',
            price: 499900,
            images: [
              'https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=900&auto=format&fit=crop&q=80',
            ],
            availableSizes: ['M'],
            variants: [],
            category: 'Dresses',
          ),
          variant: ProductVariant(
            id: 'v1_plum',
            title: 'Plum Noir / M',
            size: 'M',
            colorName: 'Plum Noir',
            colorHex: '0xFF2B1E3F',
            price: 499900,
          ),
          quantity: 1,
        ),
      ],
      trackingSteps: [
        TrackingStep(
          title: 'Delivered',
          description: 'Delivered to recipient at Vasant Vihar.',
          date: DateTime.now().subtract(const Duration(days: 11)),
          isCompleted: true,
          isCurrent: true,
        ),
      ],
    ),
  ];

  @override
  Future<List<Order>> getOrders() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.from(_orders);
  }

  @override
  Future<Order?> getOrderById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _orders.firstWhere((o) => o.id == id || o.orderNumber == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Order> createOrder({
    required List<CartLineItem> items,
    required Address address,
    required String paymentMethod,
    required int subtotal,
    required int discount,
    required int shippingFee,
    required int total,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final randomDigits = 10000 + Random().nextInt(90000);
    final order = Order(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: 'CLY-$randomDigits',
      orderDate: DateTime.now(),
      items: List.from(items),
      shippingAddress: address,
      deliveryMethod: 'Complimentary Express (2-4 Business Days)',
      paymentMethod: paymentMethod,
      paymentStatus: paymentMethod.contains('Cash') ? 'Pending (COD)' : 'Paid',
      subtotal: subtotal,
      discount: discount,
      shippingFee: shippingFee,
      total: total,
      status: OrderStatus.placed,
      trackingSteps: [
        TrackingStep(
          title: 'Order Placed',
          description:
              'Payment authorized & order logged with Clothsy Atelier.',
          date: DateTime.now(),
          isCompleted: true,
          isCurrent: true,
        ),
        const TrackingStep(
          title: 'Packed at Atelier',
          description: 'Hand-pressed, inspected and gift packaged.',
          isCompleted: false,
        ),
        const TrackingStep(
          title: 'Shipped with Express Courier',
          description: 'Handed over to logistics carrier.',
          isCompleted: false,
        ),
        const TrackingStep(
          title: 'Out for Delivery',
          description: 'On its way to your destination address.',
          isCompleted: false,
        ),
        const TrackingStep(
          title: 'Delivered',
          description: 'Package delivered to recipient.',
          isCompleted: false,
        ),
      ],
    );

    _orders.insert(0, order);
    return order;
  }

  @override
  Future<Order> cancelOrder(String orderId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _orders.indexWhere(
      (o) => o.id == orderId || o.orderNumber == orderId,
    );
    if (index >= 0) {
      final current = _orders[index];
      final cancelled = current.copyWith(
        status: OrderStatus.cancelled,
        trackingSteps: [
          ...current.trackingSteps,
          TrackingStep(
            title: 'Order Cancelled',
            description:
                'Reason: $reason. Any prepaid amount will be refunded within 24-48 hours.',
            date: DateTime.now(),
            isCompleted: true,
            isCurrent: true,
          ),
        ],
      );
      _orders[index] = cancelled;
      return cancelled;
    }
    throw Exception('Order not found');
  }
}
