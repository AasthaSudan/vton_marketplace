import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clothsy_core/data/mappers/order_mappers.dart';
import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';
import 'package:clothsy_core/features/orders/domain/repositories/order_repository.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';
import '../../../../core/supabase/supabase_errors.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Orders through the order service: the create-order and verify-payment
/// Edge Functions and the Postgres order functions. The app never writes
/// order tables itself.
class SupabaseOrderRepository implements OrderRepository {
  final SupabaseClient _client;

  SupabaseOrderRepository(this._client);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on OrderException {
      rethrow;
    } catch (e) {
      throw ServerError.from(e).toOrderException();
    }
  }

  Future<Order> _require(String id) async {
    final order = await getOrderById(id);
    if (order == null) {
      throw const OrderException('Order not found', code: 'ORDER_NOT_FOUND');
    }
    return order;
  }

  @override
  Future<List<Order>> getOrders() => _guard(() async {
    final rows = await _client
        .from('orders')
        .select(OrderMappers.orderSelect)
        .neq('payment_status', 'failed')
        .order('created_at', ascending: false);
    return rows.map(OrderMappers.order).toList();
  });

  @override
  Future<Order?> getOrderById(String id) => _guard(() async {
    final row = await _client
        .from('orders')
        .select(OrderMappers.orderSelect)
        .eq(_uuid.hasMatch(id) ? 'id' : 'order_number', id)
        .maybeSingle();
    return row == null ? null : OrderMappers.order(row);
  });

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
  }) => _guard(() async {
    final res = await _client.functions.invoke(
      'create-order',
      body: {
        'items': [
          for (final item in items)
            {'variant_id': item.variant.id, 'quantity': item.quantity},
        ],
        'address_id': address.id,
        'payment_method': OrderMappers.paymentMethodCode(method),
        'payment_label': paymentLabel,
        'coupon_code': couponCode,
        'idempotency_key': idempotencyKey,
        'expected_total': expectedTotal,
      },
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final order = await _require(data['order_id'] as String);
    final payment = data['payment'];
    if (payment is! Map) return order;
    return order.copyWith(
      paymentIntent: PaymentIntent(
        provider: payment['provider'] as String,
        keyId: payment['key_id'] as String,
        gatewayOrderId: payment['provider_order_id'] as String,
      ),
    );
  });

  @override
  Future<Order> confirmPayment(
    String orderId, {
    required String paymentRef,
    String? signature,
    String? gatewayOrderId,
  }) => _guard(() async {
    final res = await _client.functions.invoke(
      'verify-payment',
      body: {
        'order_id': orderId,
        'provider_order_id': gatewayOrderId,
        'provider_payment_id': paymentRef,
        'signature': signature ?? '',
      },
    );
    if (res.status == 202) {
      // The gateway has not captured it yet; the webhook will confirm.
      throw const OrderException('Confirming your payment', code: 'CONFIRMING');
    }
    return _require(orderId);
  });

  @override
  Future<Order> failPayment(String orderId, String reason) => _guard(() async {
    await _client.rpc(
      'fail_payment',
      params: {'p_order_id': orderId, 'p_reason': reason},
    );
    return _require(orderId);
  });

  @override
  Future<Order> cancelOrder(String orderId, String reason) => _guard(() async {
    await _client.rpc(
      'cancel_order',
      params: {'p_order_id': orderId, 'p_reason': reason},
    );
    return _require(orderId);
  });

  @override
  Future<Order> cancelSellerOrder(
    String orderId,
    String sellerOrderId,
    String reason,
  ) => _guard(() async {
    await _client.rpc(
      'cancel_seller_order',
      params: {
        'p_order_id': orderId,
        'p_seller_order_id': sellerOrderId,
        'p_reason': reason,
      },
    );
    return _require(orderId);
  });
}
