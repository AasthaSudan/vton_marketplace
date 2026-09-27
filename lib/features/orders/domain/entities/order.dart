import 'package:clothsy_shop/features/address/domain/entities/address.dart';
import 'package:clothsy_shop/features/cart/domain/entities/cart_item.dart';

enum OrderStatus {
  placed,
  packed,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
  returned;

  String get label {
    switch (this) {
      case OrderStatus.placed:
        return 'Order Placed';
      case OrderStatus.packed:
        return 'Packed at Atelier';
      case OrderStatus.shipped:
        return 'Shipped with Express';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.returned:
        return 'Returned';
    }
  }
}

class TrackingStep {
  final String title;
  final String description;
  final DateTime? date;
  final bool isCompleted;
  final bool isCurrent;

  const TrackingStep({
    required this.title,
    required this.description,
    this.date,
    this.isCompleted = false,
    this.isCurrent = false,
  });
}

class Order {
  final String id;
  final String orderNumber;
  final DateTime orderDate;
  final List<CartLineItem> items;
  final Address shippingAddress;
  final String deliveryMethod;
  final String paymentMethod;
  final String paymentStatus; // Paid, Pending, COD
  final num subtotal;
  final num discount;
  final num shippingFee;
  final num total;
  final OrderStatus status;
  final List<TrackingStep> trackingSteps;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.orderDate,
    required this.items,
    required this.shippingAddress,
    this.deliveryMethod = 'Complimentary Express (2-4 Days)',
    required this.paymentMethod,
    this.paymentStatus = 'Paid',
    required this.subtotal,
    this.discount = 0,
    this.shippingFee = 0,
    required this.total,
    this.status = OrderStatus.placed,
    this.trackingSteps = const [],
  });

  bool get canBeCancelled =>
      status == OrderStatus.placed || status == OrderStatus.packed;

  Order copyWith({
    String? id,
    String? orderNumber,
    DateTime? orderDate,
    List<CartLineItem>? items,
    Address? shippingAddress,
    String? deliveryMethod,
    String? paymentMethod,
    String? paymentStatus,
    num? subtotal,
    num? discount,
    num? shippingFee,
    num? total,
    OrderStatus? status,
    List<TrackingStep>? trackingSteps,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      items: items ?? this.items,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      shippingFee: shippingFee ?? this.shippingFee,
      total: total ?? this.total,
      status: status ?? this.status,
      trackingSteps: trackingSteps ?? this.trackingSteps,
    );
  }
}
