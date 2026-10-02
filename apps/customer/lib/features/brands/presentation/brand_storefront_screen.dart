import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/features/catalog/domain/entities/seller.dart';
import 'package:clothsy_core/shared/widgets/badges/seller_badge.dart';
import 'package:clothsy_core/shared/widgets/cards/product_card.dart';
import 'package:clothsy_core/shared/widgets/feedback/empty_state_view.dart';
import 'package:clothsy_core/shared/widgets/feedback/error_state_view.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';
import '../../wishlist/presentation/providers/wishlist_provider.dart';

/// A brand's storefront: banner, story, policies and its products
/// (Blueprint, section 25).
class BrandStorefrontScreen extends ConsumerWidget {
  final String sellerId;

  const BrandStorefrontScreen({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final seller = ref.watch(sellerProvider(sellerId));

    return Scaffold(
      backgroundColor: colors.background,
      body: seller.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateView(
          message: 'We could not load this brand. $err',
          onRetry: () => ref.invalidate(sellerProvider(sellerId)),
        ),
        data: (s) {
          if (s == null) {
            return EmptyStateView(
              icon: Icons.storefront_outlined,
              title: 'Brand not found',
              message: 'This brand is no longer on Clothsy.',
              actionText: 'See all brands',
              onActionPressed: () => context.go('/brands'),
            );
          }
          return _Storefront(seller: s);
        },
      ),
    );
  }
}

class _Storefront extends ConsumerWidget {
  final Seller seller;

  const _Storefront({required this.seller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final products = ref.watch(sellerProductsProvider(seller.id));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 180,
          backgroundColor: colors.surface,
          title: Text(
            seller.name,
            style: AppTypography.h3(color: colors.textPrimary),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: seller.bannerUrl == null
                ? Container(color: colors.surfaceMuted)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: seller.bannerUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            Container(color: colors.surfaceMuted),
                      ),
                      Container(color: AppColors.overlay.withOpacity(0.25)),
                    ],
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SellerAvatar(seller: seller, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  seller.name,
                                  style: AppTypography.h1(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (seller.isVerified) ...[
                                const SizedBox(width: 6),
                                const VerifiedBadge(size: 20),
                              ],
                            ],
                          ),
                          Text(
                            seller.tagline,
                            style: AppTypography.caption(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Stat(value: seller.followersLabel, label: 'Followers'),
                    _Stat(
                      value: '★ ${seller.rating.toStringAsFixed(1)}',
                      label: 'Rating',
                    ),
                    _Stat(value: seller.city, label: 'Based in'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'About',
                  style: AppTypography.h3(color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  seller.story,
                  style: AppTypography.body(color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: Column(
                    children: [
                      _Policy(
                        icon: Icons.inventory_2_outlined,
                        text:
                            'Ships within ${seller.dispatchDays} working days',
                      ),
                      const SizedBox(height: 8),
                      _Policy(
                        icon: Icons.assignment_return_outlined,
                        text:
                            'Returns accepted for ${seller.returnWindowDays} days after delivery',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Shop ${seller.name}',
                  style: AppTypography.h2(color: colors.textPrimary),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        products.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (err, _) => SliverToBoxAdapter(
            child: ErrorStateView(
              message: 'We could not load products. $err',
              onRetry: () => ref.invalidate(sellerProductsProvider(seller.id)),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('New styles are coming soon.')),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const ProductCardGridDelegate(),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = list[index];
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
                    onTap: () => context.push('/product/${product.id}'),
                    onWishlistToggle: () => ref
                        .read(wishlistProvider.notifier)
                        .toggleWishlist(product),
                  );
                }, childCount: list.length),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h3(color: colors.textPrimary),
          ),
          Text(
            label,
            style: AppTypography.caption(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Policy extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Policy({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}
