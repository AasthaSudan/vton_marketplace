class ProductVariant {
  final String id;
  final String title;
  final String size;
  final String colorName;
  final String colorHex;
  final int price;
  final int? originalPrice;
  final int inventoryQuantity;
  final String? imageUrl;

  const ProductVariant({
    required this.id,
    required this.title,
    required this.size,
    required this.colorName,
    required this.colorHex,
    required this.price,
    this.originalPrice,
    this.inventoryQuantity = 10,
    this.imageUrl,
  });

  bool get isAvailable => inventoryQuantity > 0;
}

class Product {
  final String id;
  final String handle;
  final String title;

  /// The seller (brand storefront) this product belongs to.
  final String sellerId;

  /// Display name of the seller / brand.
  final String brand;
  final String description;
  final int price;
  final int? originalPrice;
  final List<String> images;
  final List<String> availableSizes;
  final List<ProductVariant> variants;
  final String category;
  final double rating;
  final int reviewCount;
  final bool isTryonEligible;
  final bool isNew;
  final bool isFeatured;
  final List<String> tags;

  const Product({
    required this.id,
    required this.handle,
    required this.title,
    required this.sellerId,
    required this.brand,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.images,
    required this.availableSizes,
    required this.variants,
    required this.category,
    this.rating = 4.8,
    this.reviewCount = 42,
    this.isTryonEligible = true,
    this.isNew = false,
    this.isFeatured = false,
    this.tags = const [],
  });

  String get primaryImage => images.isNotEmpty ? images.first : '';
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  int get discountPercentage {
    if (!hasDiscount) return 0;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }
}
