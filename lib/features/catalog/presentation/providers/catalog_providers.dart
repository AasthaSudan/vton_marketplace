import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../domain/entities/banner.dart';
import '../../domain/entities/collection.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl();
});

final featuredBannersProvider = FutureProvider<List<PromoBannerItem>>((
  ref,
) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getFeaturedBanners();
});

final categoriesProvider = FutureProvider<List<ProductCollection>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getCategories();
});

class SelectedCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void select(String category) => state = category;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String>(
      SelectedCategoryNotifier.new,
    );

class SortOptionNotifier extends Notifier<String> {
  @override
  String build() => 'popular';

  void setSort(String sort) => state = sort;
}

final sortOptionProvider = NotifierProvider<SortOptionNotifier, String>(
  SortOptionNotifier.new,
);

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final category = ref.watch(selectedCategoryProvider);
  final sort = ref.watch(sortOptionProvider);
  return repo.getProducts(category: category, sortBy: sort);
});

final bestPicksProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getBestPicks();
});

final productDetailProvider = FutureProvider.family<Product?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getProductById(id);
});

final recommendationsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  productId,
) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getRecommendations(productId);
});

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

final searchResultsProvider = FutureProvider<List<Product>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.searchProducts(query);
});
