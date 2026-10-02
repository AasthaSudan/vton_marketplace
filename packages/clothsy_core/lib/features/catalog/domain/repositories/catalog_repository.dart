import '../entities/banner.dart';
import '../entities/collection.dart';
import '../entities/product.dart';
import '../entities/product_filter.dart';
import '../entities/seller.dart';

abstract class CatalogRepository {
  Future<List<PromoBannerItem>> getFeaturedBanners();
  Future<List<ProductCollection>> getCategories();

  /// Live products, newest pages first. [page] starts at 1; a page shorter
  /// than [limit] is the last one.
  Future<List<Product>> getProducts({
    String? category,
    int page = 1,
    int limit = 20,
    String? sortBy,
    ProductFilter filter = ProductFilter.none,
  });
  Future<Product?> getProductById(String id);
  Future<List<Product>> searchProducts(String query);
  Future<List<Product>> getBestPicks();
  Future<List<Product>> getRecommendations(String productId);

  /// Every approved brand / seller, for the brand directory.
  Future<List<Seller>> getSellers();
  Future<Seller?> getSellerById(String id);

  /// Live products of one seller, for its storefront.
  Future<List<Product>> getProductsBySeller(String sellerId);
}
