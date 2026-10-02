import 'product.dart';

/// Filters for Explore and listings (Blueprint fig. 14: size, price, colour,
/// brand). Prices are paise; an empty filter matches everything.
class ProductFilter {
  final Set<String> sizes;
  final int? minPrice;
  final int? maxPrice;
  final Set<String> sellerIds;

  const ProductFilter({
    this.sizes = const {},
    this.minPrice,
    this.maxPrice,
    this.sellerIds = const {},
  });

  static const none = ProductFilter();

  bool get isEmpty =>
      sizes.isEmpty &&
      minPrice == null &&
      maxPrice == null &&
      sellerIds.isEmpty;

  /// How many filter groups are in use, for the "Filters (2)" badge.
  int get activeCount =>
      (sizes.isEmpty ? 0 : 1) +
      (minPrice == null && maxPrice == null ? 0 : 1) +
      (sellerIds.isEmpty ? 0 : 1);

  bool matches(Product product) {
    if (sellerIds.isNotEmpty && !sellerIds.contains(product.sellerId)) {
      return false;
    }
    if (minPrice != null && product.price < minPrice!) return false;
    if (maxPrice != null && product.price > maxPrice!) return false;
    if (sizes.isNotEmpty &&
        !product.variants.any((v) => v.isAvailable && sizes.contains(v.size)) &&
        !product.availableSizes.any(sizes.contains)) {
      return false;
    }
    return true;
  }

  ProductFilter copyWith({
    Set<String>? sizes,
    int? minPrice,
    int? maxPrice,
    bool clearPrice = false,
    Set<String>? sellerIds,
  }) {
    return ProductFilter(
      sizes: sizes ?? this.sizes,
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      sellerIds: sellerIds ?? this.sellerIds,
    );
  }
}

/// Price bands offered in the filter sheet, bounds in paise.
enum PriceBand {
  under2000('Under ₹2,000', null, 199999),
  upTo5000('₹2,000 – ₹5,000', 200000, 500000),
  upTo10000('₹5,000 – ₹10,000', 500000, 1000000),
  above10000('₹10,000 and up', 1000000, null);

  final String label;
  final int? min;
  final int? max;

  const PriceBand(this.label, this.min, this.max);

  bool isSelectedIn(ProductFilter filter) =>
      filter.minPrice == min && filter.maxPrice == max;
}
