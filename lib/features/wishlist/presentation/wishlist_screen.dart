import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/badges/cart_badge_icon.dart';
import '../../../shared/widgets/cards/product_card.dart';
import '../../../shared/widgets/feedback/empty_state_view.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import 'providers/wishlist_provider.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final wishlist = ref.watch(wishlistProvider);
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Saved Wishlist (${wishlist.length})',
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
      body: wishlist.isEmpty
          ? EmptyStateView(
              icon: Icons.favorite_outline_rounded,
              title: 'Your Wishlist is Empty',
              message: 'Save pieces you love to preview outfits, compare styles, and get price drop alerts.',
              actionText: 'Explore Collection',
              onActionPressed: () => context.go('/explore'),
            )
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.55,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
              ),
              itemCount: wishlist.length,
              itemBuilder: (context, index) {
                final product = wishlist[index];
                return ProductCard(
                  id: product.id,
                  brand: product.brand,
                  title: product.title,
                  price: product.price,
                  originalPrice: product.originalPrice,
                  imageUrl: product.primaryImage,
                  isWishlisted: true,
                  isTriedOn: product.isTryonEligible,
                  onTap: () => context.push('/product/${product.id}'),
                  onWishlistToggle: () {
                    ref.read(wishlistProvider.notifier).toggleWishlist(product);
                  },
                );
              },
            ),
    );
  }
}
