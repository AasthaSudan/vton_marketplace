import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product_filter.dart';
import 'package:clothsy_core/shared/widgets/badges/cart_badge_icon.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/secondary_button.dart';
import 'package:clothsy_core/shared/widgets/cards/product_card.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_bottom_sheet.dart';
import 'package:clothsy_core/shared/widgets/feedback/empty_state_view.dart';
import 'package:clothsy_core/shared/widgets/feedback/error_state_view.dart';
import 'package:clothsy_core/shared/widgets/feedback/skeleton_loader.dart';
import 'package:clothsy_core/shared/widgets/inputs/clothsy_search_bar.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import '../../tryon/presentation/providers/tryon_provider.dart';
import '../../wishlist/presentation/providers/wishlist_provider.dart';
import 'providers/catalog_providers.dart';

/// Explore: browse by category with sort and filters (size, price, brand),
/// loading more as the shopper scrolls (Blueprint section 25, fig. 14).
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  static const _sortOptions = {
    'popular': 'Most popular',
    'price_low_high': 'Price: low to high',
    'price_high_low': 'Price: high to low',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final feedAsync = ref.watch(exploreFeedProvider);
    final currentSort = ref.watch(sortOptionProvider);
    final filter = ref.watch(productFilterProvider);
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          selectedCategory == 'All' ? 'Explore' : selectedCategory,
          style: AppTypography.h3(color: colors.textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CartBadgeIcon(
              count: cartCount,
              onTap: () => context.go('/bag'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ClothsySearchBar(
              readOnly: true,
              onTap: () => context.push('/search'),
              onFilterTap: () => _FilterSheet.show(context),
            ),
          ),

          // Category chips
          categoriesAsync.when(
            loading: () => const SizedBox(height: 48),
            error: (_, _) => const SizedBox.shrink(),
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
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected =
                        selectedCategory.toLowerCase() ==
                        cat.title.toLowerCase();
                    return _Chip(
                      label: cat.title,
                      selected: isSelected,
                      onTap: () => ref
                          .read(selectedCategoryProvider.notifier)
                          .select(cat.title),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 6),

          // Count, filters and sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    feedAsync.when(
                      loading: () => 'Loading…',
                      error: (_, _) => '',
                      data: (feed) =>
                          '${feed.items.length}${feed.hasMore ? '+' : ''} pieces',
                    ),
                    style: AppTypography.caption(
                      color: colors.textSecondary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                PressableScale(
                  onTap: () => _FilterSheet.show(context),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 16, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        filter.isEmpty
                            ? _sortOptions[currentSort] ?? 'Sort & filter'
                            : 'Filters (${filter.activeCount})',
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

          Expanded(
            child: feedAsync.when(
              loading: () => GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                gridDelegate: const ProductCardGridDelegate(),
                itemCount: 4,
                itemBuilder: (_, _) => const ProductCardSkeleton(),
              ),
              error: (_, _) => ErrorStateView(
                message:
                    "We couldn't load these pieces. Check your "
                    'connection and try again.',
                onRetry: () => ref.invalidate(exploreFeedProvider),
              ),
              data: (feed) {
                if (feed.items.isEmpty) {
                  return filter.isEmpty
                      ? EmptyStateView(
                          icon: Icons.checkroom_outlined,
                          title: 'Nothing in $selectedCategory yet',
                          message:
                              'New pieces land here often. Try another '
                              'category for now.',
                          actionText: 'See everything',
                          onActionPressed: () => ref
                              .read(selectedCategoryProvider.notifier)
                              .select('All'),
                        )
                      : EmptyStateView(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'No pieces match these filters',
                          message: 'Try fewer filters or another category.',
                          actionText: 'Clear filters',
                          onActionPressed: () =>
                              ref.read(productFilterProvider.notifier).clear(),
                        );
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 400) {
                      ref.read(exploreFeedProvider.notifier).loadMore();
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        sliver: SliverGrid(
                          gridDelegate: const ProductCardGridDelegate(),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final product = feed.items[index];
                            return ProductCard(
                              id: product.id,
                              brand: product.brand,
                              title: product.title,
                              price: product.price,
                              originalPrice: product.originalPrice,
                              imageUrl: product.primaryImage,
                              isWishlisted: ref.watch(
                                isProductWishlistedProvider(product.id),
                              ),
                              isTriedOn: ref
                                  .watch(triedOnProductIdsProvider)
                                  .contains(product.id),
                              onTap: () =>
                                  context.push('/product/${product.id}'),
                              onWishlistToggle: () => ref
                                  .read(wishlistProvider.notifier)
                                  .toggleWishlist(product),
                            );
                          }, childCount: feed.items.length),
                        ),
                      ),
                      if (feed.loadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.caption(
              color: selected ? colors.onPrimary : colors.textPrimary,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sort plus size, price and brand filters. Changes apply on "Show results".
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  static Future<void> show(BuildContext context) {
    return ClothsyBottomSheet.show(
      context: context,
      title: 'Sort & filter',
      subtitle: "Find exactly what you're after",
      child: const _FilterSheet(),
    );
  }

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  static const _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  late String _sort = ref.read(sortOptionProvider);
  late ProductFilter _filter = ref.read(productFilterProvider);

  Set<String> _toggled(Set<String> set, String value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sellers = ref.watch(sellersProvider).asData?.value ?? const [];

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: AppTypography.bodyMedium(
          color: colors.textPrimary,
          weight: FontWeight.w700,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading('Sort by'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in CatalogScreen._sortOptions.entries)
                _Chip(
                  label: entry.value,
                  selected: _sort == entry.key,
                  onTap: () => setState(() => _sort = entry.key),
                ),
            ],
          ),
          heading('Price'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final band in PriceBand.values)
                _Chip(
                  label: band.label,
                  selected: band.isSelectedIn(_filter),
                  onTap: () => setState(() {
                    _filter = band.isSelectedIn(_filter)
                        ? _filter.copyWith(clearPrice: true)
                        : _filter
                              .copyWith(clearPrice: true)
                              .copyWith(minPrice: band.min, maxPrice: band.max);
                  }),
                ),
            ],
          ),
          heading('Size'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in _sizes)
                _Chip(
                  label: size,
                  selected: _filter.sizes.contains(size),
                  onTap: () => setState(() {
                    _filter = _filter.copyWith(
                      sizes: _toggled(_filter.sizes, size),
                    );
                  }),
                ),
            ],
          ),
          if (sellers.isNotEmpty) ...[
            heading('Brand'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final seller in sellers)
                  _Chip(
                    label: seller.name,
                    selected: _filter.sellerIds.contains(seller.id),
                    onTap: () => setState(() {
                      _filter = _filter.copyWith(
                        sellerIds: _toggled(_filter.sellerIds, seller.id),
                      );
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  text: 'Clear all',
                  onPressed: () => setState(() {
                    _filter = ProductFilter.none;
                    _sort = 'popular';
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  text: 'Show results',
                  onPressed: () {
                    ref.read(sortOptionProvider.notifier).setSort(_sort);
                    ref.read(productFilterProvider.notifier).apply(_filter);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
