import '../entities/banner.dart';
import '../entities/collection.dart';
import '../entities/product.dart';

abstract class CatalogRepository {
  Future<List<PromoBannerItem>> getFeaturedBanners();
  Future<List<ProductCollection>> getCategories();
  Future<List<Product>> getProducts({
    String? category,
    int page = 1,
    int limit = 20,
    String? sortBy,
  });
  Future<Product?> getProductById(String id);
  Future<List<Product>> searchProducts(String query);
  Future<List<Product>> getBestPicks();
  Future<List<Product>> getRecommendations(String productId);
}
