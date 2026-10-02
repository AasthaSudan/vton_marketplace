import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/mock_catalog_repository.dart';
import 'package:clothsy_core/features/catalog/domain/entities/banner.dart';
import 'package:clothsy_core/features/catalog/domain/entities/collection.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product_filter.dart';
import 'package:clothsy_core/features/catalog/domain/entities/seller.dart';
import 'package:clothsy_core/features/catalog/domain/repositories/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return MockCatalogRepository();
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

class ProductFilterNotifier extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => ProductFilter.none;

  void apply(ProductFilter filter) => state = filter;
  void clear() => state = ProductFilter.none;
}

/// Size / price / brand filters for Explore.
final productFilterProvider =
    NotifierProvider<ProductFilterNotifier, ProductFilter>(
      ProductFilterNotifier.new,
    );

/// Every live product, unfiltered — e.g. the Try-On garment tray, which must
/// not change when Explore's category or filters do.
final allProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getProducts(limit: 100);
});

/// One page of Explore, plus whether more can be loaded.
class ExploreFeed {
  final List<Product> items;
  final bool hasMore;
  final bool loadingMore;

  const ExploreFeed({
    this.items = const [],
    this.hasMore = true,
    this.loadingMore = false,
  });
}

/// Explore grid for the selected category, sort and filters, loaded a page
/// at a time as the shopper scrolls.
class ExploreFeedNotifier extends AsyncNotifier<ExploreFeed> {
  static const pageSize = 12;
  int _page = 1;
  String _category = 'All';
  String _sort = 'popular';
  ProductFilter _filter = ProductFilter.none;

  @override
  Future<ExploreFeed> build() async {
    // Watching these restarts the feed from page 1 whenever they change.
    _category = ref.watch(selectedCategoryProvider);
    _sort = ref.watch(sortOptionProvider);
    _filter = ref.watch(productFilterProvider);
    _page = 1;
    final items = await _fetch(1);
    return ExploreFeed(items: items, hasMore: items.length == pageSize);
  }

  Future<List<Product>> _fetch(int page) {
    return ref
        .read(catalogRepositoryProvider)
        .getProducts(
          category: _category,
          sortBy: _sort,
          filter: _filter,
          page: page,
          limit: pageSize,
        );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(
      ExploreFeed(items: current.items, hasMore: true, loadingMore: true),
    );
    final next = await _fetch(_page + 1);
    if (!ref.mounted) return;
    _page++;
    state = AsyncData(
      ExploreFeed(
        items: [...current.items, ...next],
        hasMore: next.length == pageSize,
      ),
    );
  }
}

final exploreFeedProvider =
    AsyncNotifierProvider<ExploreFeedNotifier, ExploreFeed>(
      ExploreFeedNotifier.new,
    );

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

/// Auto-disposed so every visit to Search starts fresh.
final searchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

final searchResultsProvider = FutureProvider.autoDispose<List<Product>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.searchProducts(query);
});

/// Every approved brand, for the directory and the Home "Shop by brand" strip.
final sellersProvider = FutureProvider<List<Seller>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getSellers();
});

final sellerProvider = FutureProvider.family<Seller?, String>((
  ref,
  sellerId,
) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getSellerById(sellerId);
});

final sellerProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  sellerId,
) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.getProductsBySeller(sellerId);
});
