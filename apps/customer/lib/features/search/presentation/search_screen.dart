import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/shared/widgets/cards/product_card.dart';
import 'package:clothsy_core/shared/widgets/feedback/error_state_view.dart';
import 'package:clothsy_core/shared/widgets/feedback/skeleton_loader.dart';
import 'package:clothsy_core/shared/widgets/inputs/clothsy_search_bar.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';
import '../../tryon/presentation/providers/tryon_provider.dart';
import '../../wishlist/presentation/providers/wishlist_provider.dart';
import 'providers/recent_searches_provider.dart';

/// Search with recent and trending searches (Blueprint section 25). Typing is
/// debounced so the catalogue is not queried on every keystroke.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _debounce = Duration(milliseconds: 350);
  static const _trendingSearches = [
    'Silk Maxi Dress',
    'Linen Blazer',
    'Lavender Hoodie',
    'Cashmere Knit',
    'Leather Tote',
    'Noor Atelier',
  ];

  final _searchController = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) ref.read(searchQueryProvider.notifier).setQuery(query);
    });
  }

  /// Runs [term] now (tapped suggestion or keyboard search) and remembers it.
  void _searchNow(String term) {
    _timer?.cancel();
    _searchController.text = term;
    ref.read(searchQueryProvider.notifier).setQuery(term);
    ref.read(recentSearchesProvider.notifier).add(term);
  }

  void _openProduct(Product product) {
    ref.read(recentSearchesProvider.notifier).add(_searchController.text);
    context.push('/product/${product.id}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentQuery = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Search',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ClothsySearchBar(
              controller: _searchController,
              autoFocus: true,
              showFilterButton: false,
              hintText: 'Search styles, brands and more',
              onChanged: _onChanged,
              onSubmitted: _searchNow,
            ),
          ),
          Expanded(
            child: currentQuery.trim().isEmpty
                ? _buildSuggestions(context)
                : resultsAsync.when(
                    loading: () => GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      gridDelegate: const ProductCardGridDelegate(),
                      itemCount: 4,
                      itemBuilder: (_, _) => const ProductCardSkeleton(),
                    ),
                    error: (_, _) => ErrorStateView(
                      message:
                          "Search isn't responding right now. Please "
                          'try again.',
                      onRetry: () => ref.invalidate(searchResultsProvider),
                    ),
                    data: (results) => results.isEmpty
                        ? _buildNoMatches(context)
                        : _buildGrid(results),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Product> products, {bool shrink = false}) {
    final triedOn = ref.watch(triedOnProductIdsProvider);
    return GridView.builder(
      shrinkWrap: shrink,
      physics: shrink ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      gridDelegate: const ProductCardGridDelegate(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        return ProductCard(
          id: item.id,
          brand: item.brand,
          title: item.title,
          price: item.price,
          originalPrice: item.originalPrice,
          imageUrl: item.primaryImage,
          isWishlisted: ref.watch(isProductWishlistedProvider(item.id)),
          isTriedOn: triedOn.contains(item.id),
          onTap: () => _openProduct(item),
          onWishlistToggle: () =>
              ref.read(wishlistProvider.notifier).toggleWishlist(item),
        );
      },
    );
  }

  /// "No exact matches — here are styles close to what you're looking for."
  Widget _buildNoMatches(BuildContext context) {
    final colors = context.colors;
    final picks = ref.watch(bestPicksProvider).asData?.value ?? const [];
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ClothsyCopy.emptySearchTitle,
                style: AppTypography.h3(color: colors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                ClothsyCopy.emptySearchMessage,
                style: AppTypography.body(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        if (picks.isNotEmpty) _buildGrid(picks, shrink: true),
      ],
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    final colors = context.colors;
    final recent = ref.watch(recentSearchesProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent searches',
                  style: AppTypography.h3(color: colors.textPrimary),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(recentSearchesProvider.notifier).clear(),
                child: Text(
                  'Clear',
                  style: AppTypography.caption(
                    color: colors.primary,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _chips(context, recent, Icons.history_rounded),
          const SizedBox(height: 24),
        ],
        Text(
          'Trending searches',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
        const SizedBox(height: 14),
        _chips(context, _trendingSearches, Icons.trending_up_rounded),
      ],
    );
  }

  Widget _chips(BuildContext context, List<String> terms, IconData icon) {
    final colors = context.colors;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final term in terms)
          PressableScale(
            onTap: () => _searchNow(term),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.chipRadius,
                border: Border.all(color: colors.border, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    term,
                    style: AppTypography.body(color: colors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
