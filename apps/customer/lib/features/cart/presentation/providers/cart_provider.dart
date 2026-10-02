import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/core/constants/app_constants.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/cart/domain/entities/cart_item.dart';
import 'package:clothsy_core/features/cart/domain/repositories/coupon_repository.dart';
import '../../../../core/config/app_config_provider.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../data/cart_storage.dart';
import '../../data/mock_coupon_repository.dart';

final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return MockCouponRepository();
});

/// Where the bag is kept between launches, one bag per backend.
final cartStorageProvider = Provider<CartStorage>((ref) {
  final config = ref.watch(appConfigProvider);
  return CartStorage(config.useMockBackend ? 'mock' : config.supabaseUrl);
});

/// Most units of [variant] a shopper can put in one order.
int maxQuantityFor(ProductVariant variant) =>
    min(AppConstants.maxQuantityPerLine, max(variant.inventoryQuantity, 1));

class CartNotifier extends Notifier<CartSummary> {
  @override
  CartSummary build() {
    _restore();
    return const CartSummary();
  }

  /// Brings back the saved bag with today's prices and stock. Pieces that are
  /// gone are dropped; anything added meanwhile is kept.
  Future<void> _restore() async {
    final storage = ref.read(cartStorageProvider);
    final catalog = ref.read(catalogRepositoryProvider);
    final (lines, couponCode) = await storage.load();
    if (lines.isEmpty) return;

    final restored = <CartLineItem>[];
    for (final line in lines) {
      try {
        final product = await catalog.getProductById(line.productId);
        final variant = product?.variants
            .where((v) => v.id == line.variantId && v.isAvailable)
            .firstOrNull;
        if (product == null || variant == null) continue;
        restored.add(
          CartLineItem(
            id: '${product.id}_${variant.id}',
            product: product,
            variant: variant,
            quantity: min(line.quantity, maxQuantityFor(variant)),
          ),
        );
      } catch (_) {
        // Skip a line we cannot look up; the rest of the bag still loads.
      }
    }
    if (!ref.mounted) return;

    final current = state.items;
    final merged = [
      for (final item in restored)
        if (!current.any((c) => c.variant.id == item.variant.id)) item,
      ...current,
    ];
    // Keeps any coupon applied meanwhile (and saves the merged bag).
    _updateState(items: merged);
    if (couponCode != null && state.coupon == null) {
      await applyCoupon(couponCode);
    }
  }

  void addToCart(Product product, ProductVariant variant, {int quantity = 1}) {
    final currentItems = List<CartLineItem>.from(state.items);
    final existingIndex = currentItems.indexWhere(
      (item) => item.product.id == product.id && item.variant.id == variant.id,
    );
    final cap = maxQuantityFor(variant);

    if (existingIndex >= 0) {
      final existing = currentItems[existingIndex];
      currentItems[existingIndex] = existing.copyWith(
        quantity: min(existing.quantity + quantity, cap),
      );
    } else {
      currentItems.add(
        CartLineItem(
          id: '${product.id}_${variant.id}_${DateTime.now().millisecondsSinceEpoch}',
          product: product,
          variant: variant,
          quantity: min(quantity, cap),
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
        return item.copyWith(
          quantity: min(newQty, maxQuantityFor(item.variant)),
        );
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
      _persist();
      return null;
    } on CouponException catch (e) {
      return e.message;
    } catch (_) {
      return "We couldn't check that code right now. Please try again.";
    }
  }

  void removeCoupon() {
    state = CartSummary(items: state.items);
    _persist();
  }

  void clearCart() {
    state = const CartSummary();
    _persist();
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
    _persist();
  }

  void _persist() {
    ref.read(cartStorageProvider).save([
      for (final item in state.items)
        StoredBagLine(item.product.id, item.variant.id, item.quantity),
    ], state.couponCode);
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartSummary>(
  CartNotifier.new,
);

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalCount;
});
