import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clothsy_core/data/mappers/catalog_mappers.dart';
import 'package:clothsy_core/features/catalog/domain/entities/banner.dart';
import 'package:clothsy_core/features/catalog/domain/entities/collection.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product_filter.dart';
import 'package:clothsy_core/features/catalog/domain/entities/seller.dart';
import 'package:clothsy_core/features/catalog/domain/repositories/catalog_repository.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// The live catalogue. Row level security already limits it to live
/// products from approved brands.
class SupabaseCatalogRepository implements CatalogRepository {
  final SupabaseClient _client;

  SupabaseCatalogRepository(this._client);

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _products() => _client
      .from('products')
      .select(CatalogMappers.productSelect)
      .eq('status', 'live');

  @override
  Future<List<PromoBannerItem>> getFeaturedBanners() async {
    final rows = await _client.from('banners').select().order('sort_order');
    return rows.map(CatalogMappers.banner).toList();
  }

  @override
  Future<List<ProductCollection>> getCategories() async {
    final rows = await _client.from('categories').select().order('sort_order');
    return rows.map(CatalogMappers.category).toList();
  }

  @override
  Future<List<Product>> getProducts({
    String? category,
    int page = 1,
    int limit = 20,
    String? sortBy,
    ProductFilter filter = ProductFilter.none,
  }) async {
    var query = _products();
    final handle = category?.toLowerCase();
    if (handle != null && handle != 'all') {
      query = query.contains('category_handles', [handle]);
    }
    if (filter.sellerIds.isNotEmpty) {
      query = query.inFilter('seller_id', filter.sellerIds.toList());
    }
    if (filter.minPrice != null) {
      query = query.gte('min_price', filter.minPrice!);
    }
    if (filter.maxPrice != null) {
      query = query.lte('min_price', filter.maxPrice!);
    }

    final ordered = switch (sortBy) {
      'price_low_high' => query.order('min_price'),
      'price_high_low' => query.order('min_price', ascending: false),
      'popular' => query.order('review_count', ascending: false),
      _ => query.order('sort_rank'),
    };
    final rows = await ordered.range((page - 1) * limit, page * limit - 1);
    // Size needs the variants' stock, so it is applied here.
    return rows
        .map(CatalogMappers.product)
        .where((p) => filter.sizes.isEmpty || filter.matches(p))
        .toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    final row = await _products()
        .eq(_uuid.hasMatch(id) ? 'id' : 'handle', id)
        .maybeSingle();
    return row == null ? null : CatalogMappers.product(row);
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    if (query.trim().isEmpty) return [];
    final rows = await _client
        .rpc('search_products', params: {'q': query})
        .select(CatalogMappers.productSelect);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(CatalogMappers.product)
        .toList();
  }

  @override
  Future<List<Product>> getBestPicks() async {
    final rows = await _products()
        .eq('is_featured', true)
        .order('sort_rank')
        .limit(10);
    return rows.map(CatalogMappers.product).toList();
  }

  @override
  Future<List<Product>> getRecommendations(String productId) async {
    final current = await getProductById(productId);
    if (current == null) return [];
    final rows = await _products()
        .eq('category', current.category)
        .neq('id', current.id)
        .order('sort_rank')
        .limit(3);
    final same = rows.map(CatalogMappers.product).toList();
    if (same.isNotEmpty) return same;
    return (await getBestPicks())
        .where((p) => p.id != current.id)
        .take(3)
        .toList();
  }

  @override
  Future<List<Seller>> getSellers() async {
    final rows = await _client
        .from('sellers')
        .select()
        .eq('status', 'approved')
        .order('follower_count', ascending: false);
    return rows.map(CatalogMappers.seller).toList();
  }

  @override
  Future<Seller?> getSellerById(String id) async {
    final row = await _client
        .from('sellers')
        .select()
        .eq(_uuid.hasMatch(id) ? 'id' : 'handle', id)
        .maybeSingle();
    return row == null ? null : CatalogMappers.seller(row);
  }

  @override
  Future<List<Product>> getProductsBySeller(String sellerId) async {
    final rows = await _products().eq('seller_id', sellerId).order('sort_rank');
    return rows.map(CatalogMappers.product).toList();
  }
}
