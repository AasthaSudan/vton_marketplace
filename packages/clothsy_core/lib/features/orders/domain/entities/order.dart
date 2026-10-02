import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';

/// Lifecycle of a seller order (Brand Blueprint, fig. 20).
///
/// `pendingPayment` -> `placed` happens when Clothsy confirms the payment;
/// after that the seller packs, a courier ships, and it is delivered.
enum OrderStatus {
  pendingPayment,
  placed,
  packed,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
  returned;

  String get label {
    switch (this) {
      case OrderStatus.pendingPayment:
        return 'Awaiting payment';
      case OrderStatus.placed:
        return 'Order placed';
      case OrderStatus.packed:
        return 'Packed';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.returned:
        return 'Returned';
    }
  }

  /// Position on the happy path (`pendingPayment` = 0 ... `delivered` = 5);
  /// cancelled / returned sit outside the path.
  int get progress {
    switch (this) {
      case OrderStatus.pendingPayment:
        return 0;
      case OrderStatus.placed:
        return 1;
      case OrderStatus.packed:
        return 2;
      case OrderStatus.shipped:
        return 3;
      case OrderStatus.outForDelivery:
        return 4;
      case OrderStatus.delivered:
        return 5;
      case OrderStatus.cancelled:
      case OrderStatus.returned:
        return -1;
    }
  }

  /// Still on its way to the customer (not finished and not cancelled).
  bool get isInProgress => progress >= 0 && this != OrderStatus.delivered;

  /// Can be cancelled by the customer: only before the seller ships it.
  bool get isCancellable =>
      this == OrderStatus.pendingPayment ||
      this == OrderStatus.placed ||
      this == OrderStatus.packed;
}

/// How an order was (or will be) paid.
enum PaymentStatus {
  pending,
  paid,
  cashOnDelivery,
  failed,
  refunded;

  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.cashOnDelivery:
        return 'Pay on delivery';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
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

  /// The happy-path timeline for a seller order in [status], with the steps up
  /// to and including the current one marked done. [sellerName] personalises
  /// the packing step.
  static List<TrackingStep> timeline({
    required OrderStatus status,
    required String sellerName,
    required DateTime placedAt,
  }) {
    const titles = [
      'Order placed',
      'Packed',
      'Shipped',
      'Out for delivery',
      'Delivered',
    ];
    final descriptions = [
      'Payment confirmed and the order was sent to $sellerName.',
      '$sellerName packed and quality-checked your order.',
      'Handed to the courier. Live tracking is on its way.',
      'On its way to your address today.',
      'Delivered. We hope you love it — leave a review to earn Coins.',
    ];
    // `progress` 1..5 maps to titles 0..4; pending payment shows nothing done.
    final done = status.progress.clamp(0, 5);
    return [
      for (var i = 0; i < titles.length; i++)
        TrackingStep(
          title: titles[i],
          description: descriptions[i],
          date: i == 0 && done >= 1 ? placedAt : null,
          isCompleted: i < done,
          isCurrent: i == done - 1,
        ),
    ];
  }
}

/// The part of an order that one seller fulfils and ships (Blueprint, fig. 21).
///
/// Each seller order has its own items, status, tracking and refundable total,
/// so one part can be tracked, cancelled or returned on its own.
class SellerOrder {
  final String id;

  /// Human-readable reference, e.g. `CLY-84920-A`.
  final String reference;
  final String sellerId;
  final String sellerName;
  final List<CartLineItem> items;

  /// Goods total for this seller, before discount and shipping (paise).
  final int subtotal;

  /// This seller's shipment charge (paise).
  final int shippingFee;

  /// This seller order's share of the order-level coupon discount (paise).
  final int discountShare;
  final OrderStatus status;
  final List<TrackingStep> trackingSteps;

  const SellerOrder({
    required this.id,
    required this.reference,
    required this.sellerId,
    required this.sellerName,
    required this.items,
    required this.subtotal,
    this.shippingFee = 0,
    this.discountShare = 0,
    this.status = OrderStatus.placed,
    this.trackingSteps = const [],
  });

  /// What the customer paid for this seller order — and what is refunded if
  /// it is cancelled (paise).
  int get total {
    final t = subtotal + shippingFee - discountShare;
    return t < 0 ? 0 : t;
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  bool get canBeCancelled => status.isCancellable;

  SellerOrder copyWith({
    OrderStatus? status,
    List<TrackingStep>? trackingSteps,
  }) {
    return SellerOrder(
      id: id,
      reference: reference,
      sellerId: sellerId,
      sellerName: sellerName,
      items: items,
      subtotal: subtotal,
      shippingFee: shippingFee,
      discountShare: discountShare,
      status: status ?? this.status,
      trackingSteps: trackingSteps ?? this.trackingSteps,
    );
  }
}

/// A checkout: one payment that is split into a [SellerOrder] per seller.
///
/// Money totals are derived from the seller orders so they can never disagree
/// with the parts (all amounts are integer paise).
class Order {
  final String id;
  final String orderNumber;
  final DateTime orderDate;
  final List<SellerOrder> sellerOrders;
  final Address shippingAddress;
  final String deliveryMethod;

  final PaymentMethod method;

  /// Display label, e.g. `UPI (Google Pay)` or `Cash on delivery`.
  final String paymentMethod;
  final PaymentStatus paymentStatus;

  /// The gateway order to pay with, while a prepaid order awaits payment.
  final PaymentIntent? paymentIntent;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.orderDate,
    required this.sellerOrders,
    required this.shippingAddress,
    this.deliveryMethod = 'Delivered seller-wise (2-5 days)',
    required this.method,
    required this.paymentMethod,
    this.paymentStatus = PaymentStatus.paid,
    this.paymentIntent,
  });

  /// Every line item across all sellers.
  List<CartLineItem> get items => [for (final so in sellerOrders) ...so.items];

  int get itemCount => sellerOrders.fold(0, (sum, so) => sum + so.itemCount);

  int get subtotal => sellerOrders.fold(0, (sum, so) => sum + so.subtotal);
  int get shippingFee =>
      sellerOrders.fold(0, (sum, so) => sum + so.shippingFee);
  int get discount => sellerOrders.fold(0, (sum, so) => sum + so.discountShare);
  int get total => sellerOrders.fold(0, (sum, so) => sum + so.total);

  /// Overall status: the least advanced seller order that is still in play, so
  /// "Delivered" only shows once every shipment has arrived. Falls back to
  /// cancelled / returned when nothing is in play any more.
  OrderStatus get status {
    if (sellerOrders.isEmpty) return OrderStatus.cancelled;
    final inPlay = sellerOrders
        .where(
          (so) =>
              so.status != OrderStatus.cancelled &&
              so.status != OrderStatus.returned,
        )
        .toList();
    if (inPlay.isEmpty) {
      return sellerOrders.every((so) => so.status == OrderStatus.cancelled)
          ? OrderStatus.cancelled
          : OrderStatus.returned;
    }
    return inPlay
        .reduce((a, b) => a.status.progress <= b.status.progress ? a : b)
        .status;
  }

  /// True while at least one seller order can still be cancelled.
  bool get canBeCancelled => sellerOrders.any((so) => so.canBeCancelled);

  /// Amount to be refunded for cancelled seller orders, if the order was
  /// prepaid (paise). Cash-on-delivery orders have nothing to refund.
  int get refundAmount {
    if (paymentStatus != PaymentStatus.paid &&
        paymentStatus != PaymentStatus.refunded) {
      return 0;
    }
    return sellerOrders
        .where((so) => so.status == OrderStatus.cancelled)
        .fold(0, (sum, so) => sum + so.total);
  }

  SellerOrder? sellerOrderById(String id) {
    for (final so in sellerOrders) {
      if (so.id == id) return so;
    }
    return null;
  }

  Order copyWith({
    List<SellerOrder>? sellerOrders,
    String? paymentMethod,
    PaymentStatus? paymentStatus,
    PaymentIntent? paymentIntent,
  }) {
    return Order(
      id: id,
      orderNumber: orderNumber,
      orderDate: orderDate,
      sellerOrders: sellerOrders ?? this.sellerOrders,
      shippingAddress: shippingAddress,
      deliveryMethod: deliveryMethod,
      method: method,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentIntent: paymentIntent ?? this.paymentIntent,
    );
  }
}
