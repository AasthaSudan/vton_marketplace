import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_shop/features/catalog/domain/entities/product.dart';
import '../../domain/entities/cart_item.dart';

class CartNotifier extends Notifier<CartSummary> {
  @override
  CartSummary build() {
    return const CartSummary();
  }

  void addToCart(Product product, ProductVariant variant, {int quantity = 1}) {
    final currentItems = List<CartLineItem>.from(state.items);
    final existingIndex = currentItems.indexWhere(
      (item) => item.product.id == product.id && item.variant.id == variant.id,
    );

    if (existingIndex >= 0) {
      final existing = currentItems[existingIndex];
      currentItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      currentItems.add(
        CartLineItem(
          id: '${product.id}_${variant.id}_${DateTime.now().millisecondsSinceEpoch}',
          product: product,
          variant: variant,
          quantity: quantity,
        ),
      );
    }

    _updateState(items: currentItems);
  }

  void updateQuantity(String cartItemId, int newQty) {
    if (newQty <= 0) {
      removeFromCart(cartItemId);
      return;
    }

    final currentItems = state.items.map((item) {
      if (item.id == cartItemId) {
        return item.copyWith(quantity: newQty);
      }
      return item;
    }).toList();

    _updateState(items: currentItems);
  }

  void removeFromCart(String cartItemId) {
    final currentItems = state.items.where((item) => item.id != cartItemId).toList();
    _updateState(items: currentItems);
  }

  bool applyCoupon(String code) {
    final trimmed = code.trim().toUpperCase();
    if (trimmed == 'CLOTHSY10' || trimmed == 'WELCOME10') {
      // 10% discount
      final discount = (state.subtotal * 0.10).round();
      state = CartSummary(
        items: state.items,
        couponCode: trimmed,
        discountAmount: discount,
      );
      return true;
    } else if (trimmed == 'LUXURY20') {
      // 20% discount
      final discount = (state.subtotal * 0.20).round();
      state = CartSummary(
        items: state.items,
        couponCode: trimmed,
        discountAmount: discount,
      );
      return true;
    }
    return false;
  }

  void removeCoupon() {
    state = CartSummary(
      items: state.items,
      couponCode: null,
      discountAmount: 0,
    );
  }

  void clearCart() {
    state = const CartSummary();
  }

  void _updateState({required List<CartLineItem> items}) {
    num discount = 0;
    if (state.couponCode != null) {
      final sub = items.fold<num>(0, (sum, item) => sum + item.lineTotal);
      if (state.couponCode == 'CLOTHSY10' || state.couponCode == 'WELCOME10') {
        discount = (sub * 0.10).round();
      } else if (state.couponCode == 'LUXURY20') {
        discount = (sub * 0.20).round();
      }
    }

    state = CartSummary(
      items: items,
      couponCode: state.couponCode,
      discountAmount: discount,
    );
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, CartSummary>(CartNotifier.new);

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalCount;
});
