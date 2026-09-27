import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clothsy_shop/features/cart/presentation/providers/cart_provider.dart';
import 'package:clothsy_shop/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:clothsy_shop/features/catalog/domain/entities/product.dart';
import 'package:clothsy_shop/features/wishlist/presentation/providers/wishlist_provider.dart';

void main() {
  group('CatalogRepositoryImpl', () {
    late CatalogRepositoryImpl repository;

    setUp(() {
      repository = CatalogRepositoryImpl();
    });

    test('getProducts returns all products when category is All', () async {
      final products = await repository.getProducts(category: 'All');
      expect(products.isNotEmpty, isTrue);
      expect(products.length, greaterThanOrEqualTo(5));
    });

    test('getProducts filters by category correctly', () async {
      final dresses = await repository.getProducts(category: 'Dresses');
      expect(dresses.every((p) => p.category == 'Dresses'), isTrue);
    });

    test('searchProducts finds items matching title or query', () async {
      final results = await repository.searchProducts('Silk');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.title.contains('Silk'), isTrue);
    });

    test('getProductById returns product when exists', () async {
      final product = await repository.getProductById('p1');
      expect(product, isNotNull);
      expect(product!.title, 'Silk Satin Maxi Dress');
    });

    test('getProductById returns null when does not exist', () async {
      final product = await repository.getProductById('invalid_id');
      expect(product, isNull);
    });
  });

  group('CartNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    final testProduct = Product(
      id: 'test_p1',
      handle: 'test-dress',
      title: 'Test Satin Dress',
      brand: 'Clothsy',
      description: 'Test description',
      price: 3000,
      originalPrice: 4000,
      images: ['https://example.com/image.jpg'],
      availableSizes: ['S', 'M'],
      variants: const [
        ProductVariant(
          id: 'v1',
          title: 'S / Plum',
          size: 'S',
          colorName: 'Plum',
          colorHex: '0xFF2B1E3F',
          price: 3000,
        ),
      ],
      category: 'Dresses',
    );

    test('starts with empty cart', () {
      final cart = container.read(cartProvider);
      expect(cart.isEmpty, isTrue);
      expect(cart.totalCount, 0);
      expect(cart.total, 0);
    });

    test('addToCart adds line item and computes subtotal', () {
      final notifier = container.read(cartProvider.notifier);
      notifier.addToCart(testProduct, testProduct.variants.first, quantity: 2);

      final cart = container.read(cartProvider);
      expect(cart.items.length, 1);
      expect(cart.totalCount, 2);
      expect(cart.subtotal, 6000);
      // Express shipping threshold is 1999, so shipping is free
      expect(cart.shippingFee, 0);
      expect(cart.total, 6000);
    });

    test('applyCoupon applies 10% discount for CLOTHSY10', () {
      final notifier = container.read(cartProvider.notifier);
      notifier.addToCart(testProduct, testProduct.variants.first, quantity: 1); // 3000

      final applied = notifier.applyCoupon('CLOTHSY10');
      expect(applied, isTrue);

      final cart = container.read(cartProvider);
      expect(cart.couponCode, 'CLOTHSY10');
      expect(cart.discountAmount, 300); // 10% of 3000
      expect(cart.total, 2700);
    });

    test('removeFromCart deletes item', () {
      final notifier = container.read(cartProvider.notifier);
      notifier.addToCart(testProduct, testProduct.variants.first, quantity: 1);
      final itemId = container.read(cartProvider).items.first.id;

      notifier.removeFromCart(itemId);
      expect(container.read(cartProvider).isEmpty, isTrue);
    });
  });

  group('WishlistNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    final testProduct = Product(
      id: 'wish_p1',
      handle: 'wish-dress',
      title: 'Wishlist Dress',
      brand: 'Clothsy Atelier',
      description: 'Description',
      price: 5000,
      images: const ['https://example.com/image.jpg'],
      availableSizes: const ['M'],
      variants: const [],
      category: 'Dresses',
    );

    test('toggleWishlist adds and removes product', () {
      final notifier = container.read(wishlistProvider.notifier);

      expect(notifier.isWishlisted('wish_p1'), isFalse);

      notifier.toggleWishlist(testProduct);
      expect(notifier.isWishlisted('wish_p1'), isTrue);
      expect(container.read(wishlistProvider).length, 1);

      notifier.toggleWishlist(testProduct);
      expect(notifier.isWishlisted('wish_p1'), isFalse);
      expect(container.read(wishlistProvider).isEmpty, isTrue);
    });
  });
}
