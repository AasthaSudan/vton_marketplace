import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/badges/cart_badge_icon.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/cards/product_card.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_bottom_sheet.dart';
import 'package:clothsy_core/shared/widgets/feedback/empty_state_view.dart';
import 'package:clothsy_core/shared/widgets/feedback/skeleton_loader.dart';
import 'package:clothsy_core/shared/widgets/inputs/clothsy_search_bar.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import '../../tryon/presentation/providers/tryon_provider.dart';
import '../../wishlist/presentation/providers/wishlist_provider.dart';
import 'providers/catalog_providers.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider);
    final currentSort = ref.watch(sortOptionProvider);
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          selectedCategory == 'All' ? 'Curated Catalog' : selectedCategory,
          style: AppTypography.h3(color: colors.textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CartBadgeIcon(
              count: cartCount,
              onTap: () => context.push('/cart'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ClothsySearchBar(
              readOnly: true,
              onTap: () => context.push('/search'),
              onFilterTap: () => _openFilterSortSheet(context, ref),
            ),
          ),

          // Horizontal Category Tabs
          categoriesAsync.when(
            loading: () => const SizedBox(height: 44),
            error: (context, index) => const SizedBox.shrink(),
            data: (categories) {
              return SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected =
                        selectedCategory.toLowerCase() ==
                        cat.title.toLowerCase();

                    return PressableScale(
                      onTap: () {
                        ref
                            .read(selectedCategoryProvider.notifier)
                            .select(cat.title);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.primary : colors.surface,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isSelected ? colors.primary : colors.border,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          cat.title,
                          style: AppTypography.caption(
                            color: isSelected
                                ? colors.onPrimary
                                : colors.textPrimary,
                            weight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 6),

          // Sort & items count strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                productsAsync.when(
                  loading: () => Text(
                    'Loading...',
                    style: AppTypography.caption(color: colors.textSecondary),
                  ),
                  error: (context, index) => const SizedBox.shrink(),
                  data: (items) => Text(
                    '${items.length} Pieces Available',
                    style: AppTypography.caption(
                      color: colors.textSecondary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                PressableScale(
                  onTap: () => _openFilterSortSheet(context, ref),
                  child: Row(
                    children: [
                      Icon(Icons.sort_rounded, size: 16, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _sortLabel(currentSort),
                        style: AppTypography.caption(
                          color: colors.primary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Products 2-column Grid
          Expanded(
            child: productsAsync.when(
              loading: () => GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                gridDelegate: const ProductCardGridDelegate(),
                itemCount: 4,
                itemBuilder: (context, index) => const ProductCardSkeleton(),
              ),
              error: (err, _) =>
                  Center(child: Text('Error loading products: $err')),
              data: (products) {
                if (products.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.checkroom_outlined,
                    title: 'No Items in $selectedCategory',
                    message:
                        'We are continually updating our atelier. Explore another category.',
                    actionText: 'View All',
                    onActionPressed: () {
                      ref.read(selectedCategoryProvider.notifier).select('All');
                    },
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  gridDelegate: const ProductCardGridDelegate(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isWishlisted = ref.watch(
                      isProductWishlistedProvider(product.id),
                    );

                    return ProductCard(
                      id: product.id,
                      brand: product.brand,
                      title: product.title,
                      price: product.price,
                      originalPrice: product.originalPrice,
                      imageUrl: product.primaryImage,
                      isWishlisted: isWishlisted,
                      isTriedOn: ref
                          .watch(triedOnProductIdsProvider)
                          .contains(product.id),
                      onTap: () => context.push('/product/${product.id}'),
                      onWishlistToggle: () {
                        ref
                            .read(wishlistProvider.notifier)
                            .toggleWishlist(product);
                      },
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

  String _sortLabel(String sort) {
    switch (sort) {
      case 'price_low_high':
        return 'Price: Low to High';
      case 'price_high_low':
        return 'Price: High to Low';
      case 'popular':
      default:
        return 'Most Popular';
    }
  }

  void _openFilterSortSheet(BuildContext context, WidgetRef ref) {
    final currentSort = ref.read(sortOptionProvider);

    ClothsyBottomSheet.show(
      context: context,
      title: 'Sort & Filters',
      subtitle: 'Refine your atelier curation',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort Order',
              style: AppTypography.bodyMedium(weight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildSortOption(
              context,
              ref,
              'popular',
              'Most Popular',
              currentSort,
            ),
            _buildSortOption(
              context,
              ref,
              'price_low_high',
              'Price: Low to High',
              currentSort,
            ),
            _buildSortOption(
              context,
              ref,
              'price_high_low',
              'Price: High to Low',
              currentSort,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Apply',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(
    BuildContext context,
    WidgetRef ref,
    String value,
    String label,
    String currentSort,
  ) {
    final isSelected = currentSort == value;
    final colors = context.colors;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? colors.primary : colors.textSecondary,
      ),
      title: Text(label, style: AppTypography.body(color: colors.textPrimary)),
      onTap: () {
        ref.read(sortOptionProvider.notifier).setSort(value);
        Navigator.pop(context);
      },
    );
  }
}
