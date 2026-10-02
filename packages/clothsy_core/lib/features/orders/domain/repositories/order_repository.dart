import 'package:clothsy_core/features/address/domain/entities/address.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/orders/domain/entities/order.dart';

abstract class OrderRepository {
  Future<List<Order>> getOrders();
  Future<Order?> getOrderById(String id);
  Future<Order> createOrder({
    required List<CartLineItem> items,
    required Address address,
    required String paymentMethod,
    required int subtotal,
    required int discount,
    required int shippingFee,
    required int total,
  });
  Future<Order> cancelOrder(String orderId, String reason);
}
