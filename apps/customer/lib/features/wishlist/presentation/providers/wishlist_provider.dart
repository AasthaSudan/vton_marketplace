import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';

class WishlistNotifier extends Notifier<List<Product>> {
  @override
  List<Product> build() {
    return [];
  }

  void toggleWishlist(Product product) {
    if (state.any((p) => p.id == product.id)) {
      state = state.where((p) => p.id != product.id).toList();
    } else {
      state = [...state, product];
    }
  }

  void removeFromWishlist(String productId) {
    state = state.where((p) => p.id != productId).toList();
  }

  bool isWishlisted(String productId) {
    return state.any((p) => p.id == productId);
  }
}

final wishlistProvider = NotifierProvider<WishlistNotifier, List<Product>>(
  WishlistNotifier.new,
);

final isProductWishlistedProvider = Provider.family<bool, String>((ref, id) {
  final items = ref.watch(wishlistProvider);
  return items.any((p) => p.id == id);
});
