import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';

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
    final currentItems = state.items
        .where((item) => item.id != cartItemId)
        .toList();
    _updateState(items: currentItems);
  }

  /// Coupon rates in basis points (1000 = 10%). Mock-only: the server owns
  /// coupons once the Supabase backend is in use.
  static const Map<String, int> _couponBps = {
    'CLOTHSY10': 1000,
    'WELCOME10': 1000,
    'FIRST15': 1500,
    'LUXURY20': 2000,
  };

  /// Integer paise maths, rounded half up — never floating point.
  static int _discountFor(String code, int subtotal) {
    final bps = _couponBps[code];
    if (bps == null) return 0;
    return (subtotal * bps + 5000) ~/ 10000;
  }

  bool applyCoupon(String code) {
    final trimmed = code.trim().toUpperCase();
    if (!_couponBps.containsKey(trimmed)) return false;
    state = CartSummary(
      items: state.items,
      couponCode: trimmed,
      discountAmount: _discountFor(trimmed, state.subtotal),
    );
    return true;
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
    final code = state.couponCode;
    final subtotal = items.fold<int>(0, (sum, item) => sum + item.lineTotal);
    state = CartSummary(
      items: items,
      couponCode: code,
      discountAmount: code == null ? 0 : _discountFor(code, subtotal),
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartSummary>(
  CartNotifier.new,
);

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalCount;
});
