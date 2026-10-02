import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/cart/domain/repositories/coupon_repository.dart';
import '../../data/mock_coupon_repository.dart';

final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return MockCouponRepository();
});

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

  /// Validates [code] with the coupon service and applies it to the bag.
  /// Returns null on success, or a message to show the shopper.
  Future<String?> applyCoupon(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return 'Enter a coupon code first.';
    try {
      final rule = await ref
          .read(couponRepositoryProvider)
          .validate(trimmed, goodsSubtotal: state.subtotal);
      if (!ref.mounted) return null;
      state = CartSummary(
        items: state.items,
        couponCode: rule.code,
        coupon: rule,
        discountAmount: rule.discountFor(state.subtotal),
      );
      return null;
    } on CouponException catch (e) {
      return e.message;
    } catch (_) {
      return "We couldn't check that code right now. Please try again.";
    }
  }

  void removeCoupon() {
    state = CartSummary(items: state.items);
  }

  void clearCart() {
    state = const CartSummary();
  }

  void _updateState({required List<CartLineItem> items}) {
    final coupon = state.coupon;
    final subtotal = items.fold<int>(0, (sum, item) => sum + item.lineTotal);
    state = CartSummary(
      items: items,
      couponCode: coupon?.code,
      coupon: coupon,
      discountAmount: coupon?.discountFor(subtotal) ?? 0,
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartSummary>(
  CartNotifier.new,
);

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalCount;
});
