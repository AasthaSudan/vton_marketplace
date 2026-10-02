import 'package:flutter/material.dart';
import '../../features/catalog/domain/entities/banner.dart';
import '../../features/catalog/domain/entities/collection.dart';
import '../../features/catalog/domain/entities/product.dart';
import '../../features/catalog/domain/entities/seller.dart';

/// Maps catalogue rows (PostgREST JSON) to domain entities. Pure Dart, so the
/// customer app and both panels share it and it is tested without a server.
class CatalogMappers {
  CatalogMappers._();

  /// Columns to select for a product with its brand and variants.
  static const productSelect =
      '*, seller:sellers!inner(id, name, handle), variants:product_variants(*)';

  static Seller seller(Map<String, dynamic> row) {
    return Seller(
      id: row['id'] as String,
      handle: row['handle'] as String,
      name: row['name'] as String,
      tagline: row['tagline'] as String? ?? '',
      story: row['story'] as String? ?? '',
      logoUrl: row['logo_url'] as String?,
      bannerUrl: row['banner_url'] as String?,
      city: row['city'] as String? ?? '',
      isVerified: row['is_verified'] as bool? ?? false,
      isIndependent: row['is_independent'] as bool? ?? true,
      followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      dispatchDays: (row['dispatch_days'] as num?)?.toInt() ?? 2,
      returnWindowDays: (row['return_window_days'] as num?)?.toInt() ?? 7,
    );
  }

  /// "#B9A6E0" (database) → "0xFFB9A6E0" (what the app parses).
  static String colorHex(String? hex) {
    final digits = (hex ?? '').replaceFirst('#', '');
    return digits.length == 6 ? '0xFF${digits.toUpperCase()}' : '0xFF14102B';
  }

  static ProductVariant variant(Map<String, dynamic> row) {
    return ProductVariant(
      id: row['id'] as String,
      title: row['title'] as String,
      size: row['size'] as String,
      colorName: row['color_name'] as String? ?? '',
      colorHex: colorHex(row['color_hex'] as String?),
      price: (row['price'] as num).toInt(),
      originalPrice: (row['compare_at_price'] as num?)?.toInt(),
      inventoryQuantity: (row['stock'] as num?)?.toInt() ?? 0,
      imageUrl: row['image_url'] as String?,
    );
  }

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  /// A product row with embedded `seller` and `variants` ([productSelect]).
  static Product product(Map<String, dynamic> row) {
    final variantRows =
        ((row['variants'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .where((v) => v['is_active'] as bool? ?? true)
            .toList()
          ..sort(
            (a, b) => ((a['position'] as num?) ?? 0).compareTo(
              (b['position'] as num?) ?? 0,
            ),
          );
    final variants = variantRows.map(variant).toList();

    // Sizes in size order, each once.
    final bySize = <String, int>{};
    for (final v in variantRows) {
      bySize.putIfAbsent(
        v['size'] as String,
        () => (v['size_rank'] as num?)?.toInt() ?? 100,
      );
    }
    final sizes = bySize.keys.toList()
      ..sort((a, b) => bySize[a]!.compareTo(bySize[b]!));

    final seller = row['seller'] as Map<String, dynamic>?;
    final minCompare = (row['min_compare_at_price'] as num?)?.toInt();
    final price =
        (row['min_price'] as num?)?.toInt() ??
        (variants.isEmpty ? 0 : variants.first.price);

    return Product(
      id: row['id'] as String,
      handle: row['handle'] as String,
      title: row['title'] as String,
      sellerId: row['seller_id'] as String,
      brand: seller?['name'] as String? ?? '',
      description: row['description'] as String? ?? '',
      price: price,
      originalPrice: minCompare != null && minCompare > price
          ? minCompare
          : null,
      images: _strings(row['images']),
      availableSizes: sizes,
      variants: variants,
      category: row['category'] as String? ?? '',
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
      isTryonEligible: row['is_tryon_eligible'] as bool? ?? false,
      isNew: row['is_new'] as bool? ?? false,
      isFeatured: row['is_featured'] as bool? ?? false,
      tags: _strings(row['tags']),
    );
  }

  static const _categoryIcons = <String, IconData>{
    'all': Icons.checkroom_rounded,
    'men': Icons.man_outlined,
    'women': Icons.woman_outlined,
    'dresses': Icons.dry_cleaning_outlined,
    'tops': Icons.checkroom_outlined,
    'outerwear': Icons.layers_outlined,
    'shoes': Icons.roller_skating_outlined,
    'bags': Icons.shopping_bag_outlined,
  };

  static ProductCollection category(Map<String, dynamic> row) {
    final handle = row['handle'] as String;
    return ProductCollection(
      id: row['id'] as String,
      handle: handle,
      title: row['title'] as String,
      icon: _categoryIcons[handle] ?? Icons.checkroom_outlined,
    );
  }

  static PromoBannerItem banner(Map<String, dynamic> row) {
    return PromoBannerItem(
      id: row['id'] as String,
      headline: row['headline'] as String,
      subtitle: row['subtitle'] as String? ?? '',
      ctaText: row['cta_text'] as String? ?? 'Shop now',
      imageUrl: row['image_url'] as String,
      deepLinkTarget: row['deep_link'] as String?,
    );
  }
}
