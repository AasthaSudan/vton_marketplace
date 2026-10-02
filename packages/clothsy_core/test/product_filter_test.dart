import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Product product({
  String sellerId = 'sel_a',
  int price = 300000,
  List<(String, int)> sizes = const [('M', 10)],
}) {
  return Product(
    id: 'p',
    handle: 'p',
    title: 'P',
    sellerId: sellerId,
    brand: 'Brand',
    description: '',
    price: price,
    images: const [],
    availableSizes: [for (final (s, _) in sizes) s],
    variants: [
      for (final (s, stock) in sizes)
        ProductVariant(
          id: 'v_$s',
          title: s,
          size: s,
          colorName: 'Black',
          colorHex: '0xFF000000',
          price: price,
          inventoryQuantity: stock,
        ),
    ],
    category: 'Women',
  );
}

void main() {
  group('ProductFilter', () {
    test('an empty filter matches everything', () {
      expect(ProductFilter.none.isEmpty, isTrue);
      expect(ProductFilter.none.matches(product()), isTrue);
    });

    test('filters by brand, price band and size', () {
      final filter = ProductFilter(
        sellerIds: const {'sel_a'},
        minPrice: PriceBand.upTo5000.min,
        maxPrice: PriceBand.upTo5000.max,
        sizes: const {'M'},
      );
      expect(filter.activeCount, 3);
      expect(filter.matches(product()), isTrue);
      expect(filter.matches(product(sellerId: 'sel_b')), isFalse);
      expect(filter.matches(product(price: 600000)), isFalse);
      expect(filter.matches(product(sizes: const [('L', 10)])), isFalse);
    });

    test('price bands are recognised in the filter', () {
      final filter = ProductFilter(
        minPrice: PriceBand.under2000.min,
        maxPrice: PriceBand.under2000.max,
      );
      expect(PriceBand.under2000.isSelectedIn(filter), isTrue);
      expect(PriceBand.upTo5000.isSelectedIn(filter), isFalse);
      expect(filter.copyWith(clearPrice: true).isEmpty, isTrue);
    });
  });
}
