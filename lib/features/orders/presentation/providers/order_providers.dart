import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_shop/features/address/domain/entities/address.dart';
import 'package:clothsy_shop/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_shop/features/orders/data/repositories/order_repository_impl.dart';
import 'package:clothsy_shop/features/orders/domain/entities/order.dart';
import 'package:clothsy_shop/features/orders/domain/repositories/order_repository.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl();
});

class OrdersNotifier extends Notifier<List<Order>> {
  @override
  List<Order> build() {
    _loadOrders();
    return [];
  }

  Future<void> _loadOrders() async {
    final repo = ref.read(orderRepositoryProvider);
    final list = await repo.getOrders();
    if (!ref.mounted) return;
    state = list;
  }

  Future<Order> createOrder({
    required List<CartLineItem> items,
    required Address address,
    required String paymentMethod,
    required num subtotal,
    required num discount,
    required num shippingFee,
    required num total,
  }) async {
    final repo = ref.read(orderRepositoryProvider);
    final order = await repo.createOrder(
      items: items,
      address: address,
      paymentMethod: paymentMethod,
      subtotal: subtotal,
      discount: discount,
      shippingFee: shippingFee,
      total: total,
    );
    state = [order, ...state];
    return order;
  }

  Future<Order> cancelOrder(String orderId, String reason) async {
    final repo = ref.read(orderRepositoryProvider);
    final cancelled = await repo.cancelOrder(orderId, reason);
    state = state.map((o) => o.id == orderId ? cancelled : o).toList();
    return cancelled;
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);

final orderDetailProvider = FutureProvider.family<Order?, String>((
  ref,
  id,
) async {
  final repo = ref.read(orderRepositoryProvider);
  return repo.getOrderById(id);
});
