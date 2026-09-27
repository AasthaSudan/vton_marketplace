import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/badges/cart_badge_icon.dart';
import '../../../shared/widgets/buttons/clothsy_icon_button.dart';
import '../../../shared/widgets/cards/offer_strip.dart';
import '../../../shared/widgets/cards/product_card.dart';
import '../../../shared/widgets/cards/promo_banner.dart';
import '../../../shared/widgets/feedback/clothsy_snackbar.dart';
import '../../../shared/widgets/feedback/skeleton_loader.dart';
import '../../../shared/widgets/selectors/category_chip.dart';
import '../../../shared/widgets/typography/section_header.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';
import '../../tryon/presentation/providers/tryon_provider.dart';
import '../../wishlist/presentation/providers/wishlist_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _activeBannerIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bannersAsync = ref.watch(featuredBannersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final bestPicksAsync = ref.watch(bestPicksProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      drawer: _buildAppDrawer(context),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ClothsyIconButton(
            size: 40,
            icon: Icon(Icons.menu_rounded, color: colors.primary, size: 22),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: Text(
          'Clothsy',
          style: AppTypography.display(color: colors.primary).copyWith(
            fontSize: 22,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          ClothsyIconButton(
            size: 40,
            borderColor: Colors.transparent,
            icon: Icon(Icons.search_rounded, color: colors.primary, size: 24),
            onPressed: () => context.push('/search'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CartBadgeIcon(
              count: cartCount,
              onTap: () => context.push('/cart'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: () async {
          ref.invalidate(featuredBannersProvider);
          ref.invalidate(categoriesProvider);
          ref.invalidate(bestPicksProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 36),
          children: [
            // Hero Promo Banner Carousel (Screen 2 Mockup)
            bannersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SkeletonBox(height: 195),
              ),
              error: (err, stack) => const SizedBox.shrink(),
              data: (banners) {
                if (banners.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 195,
                  child: PageView.builder(
                    itemCount: banners.length,
                    onPageChanged: (idx) =>
                        setState(() => _activeBannerIndex = idx),
                    itemBuilder: (context, index) {
                      final banner = banners[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: PromoBanner(
                          headline: banner.headline,
                          subtitle: banner.subtitle,
                          ctaText: banner.ctaText,
                          imageUrl: banner.imageUrl,
                          totalDots: banners.length,
                          activeDotIndex: _activeBannerIndex,
                          onCtaPressed: () {
                            if (banner.deepLinkTarget != null) {
                              context.go(banner.deepLinkTarget!);
                            } else {
                              context.go('/explore');
                            }
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            // Circular Categories Row (All, Men, Women, Shoes, Bags) - Equal Sized & Equal Spacing
            categoriesAsync.when(
              loading: () => LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 32) / 5;
                  final circleSize = (itemWidth - 12).clamp(44.0, 56.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        5,
                        (index) => Expanded(
                          child: Center(
                            child: SkeletonBox(
                              width: circleSize,
                              height: circleSize,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              error: (context, index) => const SizedBox.shrink(),
              data: (categories) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final itemWidth = (availableWidth - 32) / categories.length;
                    final circleSize = (itemWidth - 12).clamp(44.0, 56.0);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: categories.map((cat) {
                          final isSelected =
                              selectedCategory.toLowerCase() ==
                              cat.title.toLowerCase();
                          return Expanded(
                            child: Center(
                              child: CategoryChip(
                                circleSize: circleSize,
                                label: cat.title,
                                icon: cat.icon,
                                isSelected: isSelected,
                                onTap: () {
                                  ref
                                      .read(selectedCategoryProvider.notifier)
                                      .select(cat.title);
                                  context.go('/explore');
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Best Picks Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeader(
                title: 'Best Picks',
                actionText: 'See All',
                onActionTap: () => context.go('/explore'),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),

            // Best Picks Horizontal Carousel (Featuring Minimal Overshirt, Lavender Hoodie, Lavender Blazer)
            bestPicksAsync.when(
              loading: () => SizedBox(
                height: 320,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: const [
                    SizedBox(width: 185, child: ProductCardSkeleton()),
                    SizedBox(width: 14),
                    SizedBox(width: 185, child: ProductCardSkeleton()),
                  ],
                ),
              ),
              error: (err, _) =>
                  Center(child: Text('Error loading best picks: $err')),
              data: (products) {
                return SizedBox(
                  height: 320,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isWishlisted = ref.watch(
                        isProductWishlistedProvider(product.id),
                      );

                      return SizedBox(
                        width: 185,
                        child: ProductCard(
                          id: product.id,
                          heroTag: 'best_picks_${product.id}',
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
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            // Exclusive Offer Lilac Strip (Screen 2 Mockup bottom banner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OfferStrip(
                icon: Icons.local_offer_outlined,
                title: 'Exclusive Offer',
                subtitle: 'Extra 15% off on first order',
                onTap: () {
                  ref.read(cartProvider.notifier).applyCoupon('FIRST15');
                  ClothsySnackbar.show(
                    context,
                    message: 'Coupon FIRST15 (15% OFF) applied to your bag!',
                    type: SnackbarType.success,
                  );
                  context.push('/cart');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context) {
    final colors = context.colors;

    return Drawer(
      backgroundColor: colors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 20, color: colors.accent),
                      const SizedBox(width: 8),
                      Text(
                        'CLOTHSY',
                        style: AppTypography.display(color: colors.primary)
                            .copyWith(
                              fontSize: 22,
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Haute Couture & AI Virtual Try-On',
                    style: AppTypography.caption(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(color: colors.border.withOpacity(0.6)),

            // Drawer Nav Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                children: [
                  _buildDrawerTile(
                    context,
                    icon: Icons.home_rounded,
                    title: 'Home',
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.checkroom_rounded,
                    title: 'Explore Collection',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/explore');
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.auto_awesome,
                    title: 'Virtual Try-On Studio',
                    subtitle: 'AI Photorealistic Fitting',
                    isHighlighted: true,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/tryon');
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.favorite_outline_rounded,
                    title: 'Wishlist',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/wishlist');
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    title: 'My Bag',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/cart');
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.local_shipping_outlined,
                    title: 'Orders & Tracking',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/orders');
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.person_outline_rounded,
                    title: 'My Profile',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/profile');
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.auto_awesome_outlined,
                    title: 'Intro & Onboarding',
                    subtitle: 'Revisit welcome experience',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/onboarding');
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Clothsy v1.0.0 • FabricVTON AI',
                style: AppTypography.caption(
                  color: colors.textSecondary.withOpacity(0.7),
                ).copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    bool isHighlighted = false,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colors.accentSoft.withOpacity(0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(
          icon,
          color: isHighlighted ? colors.accent : colors.primary,
          size: 22,
        ),
        title: Text(
          title,
          style: AppTypography.bodyMedium(
            color: colors.primary,
            weight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: AppTypography.caption(
                  color: colors.textSecondary,
                ).copyWith(fontSize: 11),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: colors.textSecondary.withOpacity(0.5),
        ),
        onTap: onTap,
      ),
    );
  }
}
