import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clothsy_shop/features/cart/presentation/providers/cart_provider.dart';
import 'package:clothsy_shop/features/catalog/data/repositories/mock_catalog_repository.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_shop/features/wishlist/presentation/providers/wishlist_provider.dart';

void main() {
  group('MockCatalogRepository', () {
    late MockCatalogRepository repository;

    setUp(() {
      repository = MockCatalogRepository();
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

    test('searchProducts matches every word, in any order', () async {
      final dress = await repository.searchProducts('silk dress');
      expect(dress.map((p) => p.title), contains('Silk Satin Maxi Dress'));

      final knit = await repository.searchProducts('cashmere knit');
      expect(knit.map((p) => p.title), contains('Cashmere Blend Knit Top'));

      final byBrand = await repository.searchProducts('noor');
      expect(byBrand.every((p) => p.brand == 'Noor Atelier'), isTrue);
      expect(byBrand, isNotEmpty);

      expect(await repository.searchProducts('silk hoodie'), isEmpty);
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
      sellerId: 'sel_test',
      brand: 'Test Label',
      description: 'Test description',
      price: 300000,
      originalPrice: 400000,
      images: ['https://example.com/image.jpg'],
      availableSizes: ['S', 'M'],
      variants: const [
        ProductVariant(
          id: 'v1',
          title: 'S / Violet',
          size: 'S',
          colorName: 'Violet',
          colorHex: '0xFF5C25FC',
          price: 300000,
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
      expect(cart.subtotal, 600000);
      // Free-shipping threshold is ₹1,999 (199900 paise), so shipping is free
      expect(cart.shippingFee, 0);
      expect(cart.total, 600000);
    });

    test('applyCoupon applies 10% discount for CLOTHSY10', () async {
      final notifier = container.read(cartProvider.notifier);
      notifier.addToCart(
        testProduct,
        testProduct.variants.first,
        quantity: 1,
      ); // 3000

      expect(await notifier.applyCoupon('CLOTHSY10'), isNull);

      final cart = container.read(cartProvider);
      expect(cart.couponCode, 'CLOTHSY10');
      expect(cart.discountAmount, 30000); // 10% of ₹3,000, in paise
      expect(cart.total, 270000);
    });

    test('coupons use integer paise maths and follow the bag', () async {
      final notifier = container.read(cartProvider.notifier);
      notifier.addToCart(testProduct, testProduct.variants.first); // ₹3,000

      expect(await notifier.applyCoupon(' first15 '), isNull);
      expect(container.read(cartProvider).couponCode, 'FIRST15');
      expect(container.read(cartProvider).discountAmount, 45000);

      // The discount is recomputed when the bag changes.
      final itemId = container.read(cartProvider).items.first.id;
      notifier.updateQuantity(itemId, 3); // ₹9,000
      expect(container.read(cartProvider).discountAmount, 135000);

      notifier.removeCoupon();
      expect(container.read(cartProvider).discountAmount, 0);
    });

    test('unknown coupons are rejected and change nothing', () async {
      final notifier = container.read(cartProvider.notifier);
      notifier.addToCart(testProduct, testProduct.variants.first);
      expect(await notifier.applyCoupon('FREEMONEY'), contains("isn't valid"));
      expect(container.read(cartProvider).couponCode, isNull);
      expect(container.read(cartProvider).discountAmount, 0);
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
      sellerId: 'sel_noor',
      brand: 'Noor Atelier',
      description: 'Description',
      price: 500000,
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
