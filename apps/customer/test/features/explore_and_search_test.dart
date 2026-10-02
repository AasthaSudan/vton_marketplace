import 'package:clothsy_core/features/catalog/domain/entities/product_filter.dart';
import 'package:clothsy_shop/features/catalog/data/repositories/mock_catalog_repository.dart';
import 'package:clothsy_shop/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:clothsy_shop/features/search/presentation/providers/recent_searches_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Catalogue paging and filters', () {
    final repo = MockCatalogRepository();

    test('pages do not overlap and the last page is short', () async {
      final all = await repo.getProducts(limit: 100);
      final first = await repo.getProducts(page: 1, limit: 4);
      final second = await repo.getProducts(page: 2, limit: 4);
      expect(first.length, 4);
      expect(
        second
            .map((p) => p.id)
            .toSet()
            .intersection(first.map((p) => p.id).toSet()),
        isEmpty,
      );
      final last = await repo.getProducts(page: 3, limit: 4);
      expect(last.length, all.length - 8);
    });

    test('brand filter only returns that brand', () async {
      final noor = await repo.getProducts(
        limit: 100,
        filter: const ProductFilter(sellerIds: {'sel_noor'}),
      );
      expect(noor, isNotEmpty);
      expect(noor.every((p) => p.sellerId == 'sel_noor'), isTrue);
    });

    test('every category chip has pieces', () async {
      for (final category in await repo.getCategories()) {
        final products = await repo.getProducts(category: category.title);
        expect(products, isNotEmpty, reason: category.title);
      }
    });
  });

  group('Explore feed', () {
    test('restarts when filters change', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final everything = await container.read(exploreFeedProvider.future);
      container
          .read(productFilterProvider.notifier)
          .apply(const ProductFilter(sellerIds: {'sel_rao'}));
      final rao = await container.read(exploreFeedProvider.future);

      expect(rao.items.length, lessThan(everything.items.length));
      expect(rao.items.every((p) => p.sellerId == 'sel_rao'), isTrue);
    });
  });

  group('Recent searches', () {
    test('newest first, without duplicates, and capped', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(recentSearchesProvider.notifier);

      await notifier.add('blazer');
      await notifier.add('silk dress');
      await notifier.add('Blazer');
      expect(container.read(recentSearchesProvider), ['Blazer', 'silk dress']);

      for (var i = 0; i < 12; i++) {
        await notifier.add('term $i');
      }
      expect(
        container.read(recentSearchesProvider).length,
        RecentSearchesNotifier.max,
      );

      await notifier.clear();
      expect(container.read(recentSearchesProvider), isEmpty);
    });

    test('one-letter searches are not remembered', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(recentSearchesProvider.notifier).add(' s ');
      expect(container.read(recentSearchesProvider), isEmpty);
    });
  });
}
