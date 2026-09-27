import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/buttons/pressable_scale.dart';
import '../../../shared/widgets/cards/product_card.dart';
import '../../../shared/widgets/feedback/empty_state_view.dart';
import '../../../shared/widgets/feedback/skeleton_loader.dart';
import '../../../shared/widgets/inputs/clothsy_search_bar.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _trendingSearches = const [
    'Silk Maxi Dress',
    'Linen Blazer',
    'Slip Skirt',
    'Cashmere Knit',
    'Leather Tote',
    'Ankle Strap Heels',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    ref.read(searchQueryProvider.notifier).setQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentQuery = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Search', style: AppTypography.h3(color: colors.textPrimary)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ClothsySearchBar(
              controller: _searchController,
              autoFocus: false,
              hintText: 'Search silk, blazer, dresses, bags...',
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: currentQuery.trim().isEmpty
                ? _buildTrendingSection(context)
                : searchResultsAsync.when(
                    loading: () => GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) => const ProductCardSkeleton(),
                    ),
                    error: (err, _) => Center(child: Text('Search error: $err')),
                    data: (results) {
                      if (results.isEmpty) {
                        return EmptyStateView(
                          icon: Icons.search_off_rounded,
                          title: 'No Matching Pieces Found',
                          message: 'Try searching for "Silk", "Blazer", or explore our latest collections.',
                          actionText: 'View All Collections',
                          onActionPressed: () => context.go('/explore'),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.55,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return ProductCard(
                            id: item.id,
                            brand: item.brand,
                            title: item.title,
                            price: item.price,
                            originalPrice: item.originalPrice,
                            imageUrl: item.primaryImage,
                            onTap: () => context.push('/product/${item.id}'),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSection(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trending Searches',
            style: AppTypography.h3(color: colors.textPrimary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _trendingSearches.map((term) {
              return PressableScale(
                onTap: () {
                  _searchController.text = term;
                  _onSearch(term);
                },
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
                      Icon(Icons.trending_up_rounded, size: 14, color: colors.accent),
                      const SizedBox(width: 6),
                      Text(
                        term,
                        style: AppTypography.body(color: colors.textPrimary).copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
