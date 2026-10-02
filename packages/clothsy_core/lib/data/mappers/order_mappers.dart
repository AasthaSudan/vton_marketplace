import '../../core/constants/clothsy_copy.dart';
import '../../core/utils/currency_formatter.dart';
import '../../features/address/domain/entities/address.dart';
import '../../features/cart/domain/entities/cart_item.dart';
import '../../features/catalog/domain/entities/product.dart';
import '../../features/orders/domain/entities/order.dart';
import '../../features/payments/domain/payment_gateway.dart';
import 'catalog_mappers.dart';

/// Maps order rows to the domain Order (parent order → seller orders →
/// items), with tracking built the same way the mock builds it.
class OrderMappers {
  OrderMappers._();

  /// Columns to select for a full order.
  static const orderSelect =
      '*, seller_orders(*, order_items(*)), '
      'refunds(amount, status, seller_order_id), '
      'payments(provider, provider_order_id, state)';

  static PaymentMethod paymentMethod(String value) => switch (value) {
    'card' => PaymentMethod.card,
    'net_banking' => PaymentMethod.netBanking,
    'cod' => PaymentMethod.cashOnDelivery,
    _ => PaymentMethod.upi,
  };

  static String paymentMethodCode(PaymentMethod method) => switch (method) {
    PaymentMethod.upi => 'upi',
    PaymentMethod.card => 'card',
    PaymentMethod.netBanking => 'net_banking',
    PaymentMethod.cashOnDelivery => 'cod',
  };

  /// A part-refunded order is still a paid order; its cancelled parts carry
  /// the refunds.
  static PaymentStatus paymentStatus(String value) => switch (value) {
    'pending' => PaymentStatus.pending,
    'cod' => PaymentStatus.cashOnDelivery,
    'failed' => PaymentStatus.failed,
    'refunded' => PaymentStatus.refunded,
    _ => PaymentStatus.paid,
  };

  static OrderStatus status(String value) => switch (value) {
    'pending_payment' => OrderStatus.pendingPayment,
    'packed' => OrderStatus.packed,
    'shipped' => OrderStatus.shipped,
    'out_for_delivery' => OrderStatus.outForDelivery,
    'delivered' => OrderStatus.delivered,
    'cancelled' => OrderStatus.cancelled,
    'returned' => OrderStatus.returned,
    _ => OrderStatus.placed,
  };

  /// The address snapshot stored on the order.
  static Address address(Map<String, dynamic> json) {
    return Address(
      id: '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      street: json['line1'] as String? ?? '',
      apartment: json['line2'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pinCode: json['pin_code'] as String? ?? '',
      label: json['label'] as String? ?? 'Home',
    );
  }

  /// A bought line, rebuilt from its snapshot (prices as paid).
  static CartLineItem item(Map<String, dynamic> row, String sellerName) {
    final variant = ProductVariant(
      id: row['variant_id'] as String,
      title: row['variant_title'] as String,
      size: row['size'] as String,
      colorName: row['color_name'] as String? ?? '',
      colorHex: CatalogMappers.colorHex(row['color_hex'] as String?),
      price: (row['unit_price'] as num).toInt(),
      originalPrice: (row['compare_at_price'] as num?)?.toInt(),
      imageUrl: row['image_url'] as String?,
    );
    final image = row['image_url'] as String?;
    return CartLineItem(
      id: row['id'] as String,
      quantity: (row['quantity'] as num).toInt(),
      variant: variant,
      product: Product(
        id: row['product_id'] as String,
        handle: '',
        title: row['title'] as String,
        sellerId: row['seller_id'] as String,
        brand: sellerName,
        description: '',
        price: variant.price,
        originalPrice: variant.originalPrice,
        images: image == null ? const [] : [image],
        availableSizes: [variant.size],
        variants: [variant],
        category: '',
      ),
    );
  }

  static Order order(Map<String, dynamic> row) {
    final placedAt = DateTime.parse(row['created_at'] as String).toLocal();
    final method = paymentMethod(row['payment_method'] as String);
    final payment = paymentStatus(row['payment_status'] as String);
    final refunds = ((row['refunds'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    final parts =
        ((row['seller_orders'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) => (a['position'] as num).compareTo(b['position'] as num),
          );

    final sellerOrders = [
      for (final so in parts)
        _sellerOrder(so, placedAt, payment, method, refunds),
    ];

    PaymentIntent? intent;
    for (final p
        in ((row['payments'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()) {
      if (p['state'] == 'created') {
        intent = PaymentIntent(
          provider: p['provider'] as String,
          keyId: '',
          gatewayOrderId: p['provider_order_id'] as String,
        );
      }
    }

    return Order(
      id: row['id'] as String,
      orderNumber: row['order_number'] as String,
      orderDate: placedAt,
      sellerOrders: sellerOrders,
      shippingAddress: address(
        (row['shipping_address'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      method: method,
      paymentMethod: row['payment_label'] as String? ?? method.label,
      paymentStatus: payment,
      paymentIntent: payment == PaymentStatus.pending ? intent : null,
    );
  }

  static SellerOrder _sellerOrder(
    Map<String, dynamic> so,
    DateTime placedAt,
    PaymentStatus payment,
    PaymentMethod method,
    List<Map<String, dynamic>> refunds,
  ) {
    final name = so['seller_name'] as String;
    final st = status(so['status'] as String);
    final items =
        ((so['order_items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) => ((a['position'] as num?) ?? 0).compareTo(
              (b['position'] as num?) ?? 0,
            ),
          );
    final total = (so['total'] as num).toInt();

    List<TrackingStep> steps;
    if (st == OrderStatus.cancelled) {
      final reason = so['cancel_reason'] as String? ?? 'Cancelled';
      final cancelledAt = so['cancelled_at'] == null
          ? null
          : DateTime.parse(so['cancelled_at'] as String).toLocal();
      if (payment == PaymentStatus.failed) {
        steps = [
          TrackingStep(
            title: 'Payment failed',
            description: ClothsyCopy.paymentFailed,
            date: cancelledAt,
            isCompleted: true,
            isCurrent: true,
          ),
        ];
      } else {
        final refunded = refunds.any((r) => r['seller_order_id'] == so['id']);
        steps = [
          ...TrackingStep.timeline(
            status: OrderStatus.placed,
            sellerName: name,
            placedAt: placedAt,
          ).map(
            (s) => TrackingStep(
              title: s.title,
              description: s.description,
              date: s.date,
              isCompleted: s.isCompleted,
            ),
          ),
          TrackingStep(
            title: 'Cancelled',
            description: refunded
                ? 'Reason: $reason. ${ClothsyCopy.refundStarted(amount: CurrencyFormatter.format(total), destination: method.refundDestination)}'
                : 'Reason: $reason. ${ClothsyCopy.noPaymentTaken}',
            date: cancelledAt,
            isCompleted: true,
            isCurrent: true,
          ),
        ];
      }
    } else {
      steps = TrackingStep.timeline(
        status: st,
        sellerName: name,
        placedAt: placedAt,
      );
    }

    return SellerOrder(
      id: so['id'] as String,
      reference: so['reference'] as String,
      sellerId: so['seller_id'] as String,
      sellerName: name,
      items: [for (final i in items) item(i, name)],
      subtotal: (so['subtotal'] as num).toInt(),
      shippingFee: (so['shipping_fee'] as num).toInt(),
      discountShare: (so['discount_share'] as num).toInt(),
      status: st,
      trackingSteps: steps,
    );
  }
}
