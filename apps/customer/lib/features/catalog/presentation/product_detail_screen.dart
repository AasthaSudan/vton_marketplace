import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/badges/seller_badge.dart';
import 'package:clothsy_core/shared/widgets/buttons/clothsy_icon_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/shared/widgets/cards/product_card.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_bottom_sheet.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import 'package:clothsy_core/shared/widgets/feedback/skeleton_loader.dart';
import 'package:clothsy_core/shared/widgets/selectors/color_swatch_selector.dart';
import 'package:clothsy_core/shared/widgets/selectors/size_selector.dart';
import 'package:clothsy_core/shared/widgets/typography/price_row.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import '../../wishlist/presentation/providers/wishlist_provider.dart';
import 'providers/catalog_providers.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;
  String? _selectedSize;
  String? _selectedVariantId;
  bool _isDescriptionExpanded = false;

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final productAsync = ref.watch(productDetailProvider(widget.productId));

    return Scaffold(
      backgroundColor: colors.background,
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('Error loading product: $err')),
        ),
        data: (product) {
          if (product == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Product not found')),
            );
          }

          final isWishlisted = ref.watch(
            isProductWishlistedProvider(product.id),
          );

          // Set active size and variant
          final activeSize =
              _selectedSize ??
              (product.availableSizes.isNotEmpty
                  ? product.availableSizes.first
                  : 'M');
          final activeVariant = product.variants.firstWhere(
            (v) => _selectedVariantId != null
                ? v.id == _selectedVariantId
                : v.size == activeSize,
            orElse: () => product.variants.first,
          );

          final swatches = product.variants.map((v) {
            final hex =
                int.tryParse(v.colorHex) ??
                context.colors.textPrimary.toARGB32();
            return ColorSwatchItem(
              id: v.id,
              name: v.colorName,
              color: Color(hex),
            );
          }).toList();

          return Stack(
            children: [
              // Main scrollable body
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    // Top Bar: Back & Wishlist Buttons
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ClothsyIconButton(
                              size: 42,
                              backgroundColor: colors.surface,
                              icon: Icon(
                                Icons.chevron_left_rounded,
                                size: 24,
                                color: colors.primary,
                              ),
                              onPressed: () => context.pop(),
                            ),
                            ClothsyIconButton(
                              size: 42,
                              backgroundColor: colors.surface,
                              icon: Icon(
                                isWishlisted
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_outline_rounded,
                                size: 20,
                                color: isWishlisted
                                    ? colors.error
                                    : colors.primary,
                              ),
                              onPressed: () => ref
                                  .read(wishlistProvider.notifier)
                                  .toggleWishlist(product),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Architectural Arched Hero Image (Screen 3 Mockup)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: AspectRatio(
                          aspectRatio: 0.78,
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.colors.surfaceMuted,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(500),
                                bottom: Radius.circular(32),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withOpacity(0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Subtle leaf/plant shadow accent on the left
                                Positioned(
                                  left: -10,
                                  top: 40,
                                  child: Opacity(
                                    opacity: 0.18,
                                    child: Icon(
                                      Icons.spa_rounded,
                                      size: 140,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),

                                // Image PageView
                                PageView.builder(
                                  controller: _imagePageController,
                                  itemCount: product.images.length,
                                  onPageChanged: (idx) =>
                                      setState(() => _currentImageIndex = idx),
                                  itemBuilder: (context, idx) {
                                    return Hero(
                                      tag: idx == 0
                                          ? 'product_image_${product.id}'
                                          : 'product_gallery_${product.id}_$idx',
                                      child: CachedNetworkImage(
                                        imageUrl: product.images[idx],
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color:
                                                  context.colors.surfaceMuted,
                                            ),
                                        errorWidget: (context, url, err) =>
                                            Container(
                                              color:
                                                  context.colors.surfaceMuted,
                                              child: Icon(
                                                Icons.checkroom_rounded,
                                                size: 60,
                                                color: colors.accent,
                                              ),
                                            ),
                                      ),
                                    );
                                  },
                                ),

                                // Gallery Counter Pill Badge (Screen 3 Mockup: "1/4" centered)
                                Positioned(
                                  bottom: 16,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.18,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${_currentImageIndex + 1}/${product.images.length}',
                                        style:
                                            AppTypography.label(
                                              color: colors.onPrimary,
                                              weight: FontWeight.w700,
                                            ).copyWith(
                                              fontSize: 11,
                                              letterSpacing: 1.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Product Details Content
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Brand Kicker & Rating Row (Screen 3 Mockup)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    product.brand.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        AppTypography.label(
                                          color: colors.textSecondary,
                                          weight: FontWeight.w700,
                                        ).copyWith(
                                          letterSpacing: 2.0,
                                          fontSize: 11,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: context.colors.rating,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${product.rating}',
                                      style: AppTypography.caption(
                                        color: colors.textPrimary,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '(${product.reviewCount})',
                                      style: AppTypography.caption(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Product Title
                            Text(
                              product.title,
                              style: AppTypography.h1(color: colors.textPrimary)
                                  .copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),

                            // Who sells it — opens the brand storefront
                            SellerChip(
                              seller: ref
                                  .watch(sellerProvider(product.sellerId))
                                  .asData
                                  ?.value,
                              fallbackName: product.brand,
                              onTap: () =>
                                  context.push('/brand/${product.sellerId}'),
                            ),
                            const SizedBox(height: 12),

                            // Price Row: ₹7,999 ₹9,999 20% OFF
                            PriceRow(
                              price: activeVariant.price,
                              originalPrice:
                                  activeVariant.originalPrice ??
                                  product.originalPrice,
                              currentPriceFontSize: 24,
                            ),
                            const SizedBox(height: 20),

                            // Size Selector
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Size',
                                  style: AppTypography.bodyMedium(
                                    weight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                PressableScale(
                                  onTap: () => _openSizeGuideSheet(context),
                                  child: Text(
                                    'Size Guide',
                                    style:
                                        AppTypography.caption(
                                          color: colors.primary,
                                          weight: FontWeight.w600,
                                        ).copyWith(
                                          decoration: TextDecoration.underline,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizeSelector(
                              sizes: product.availableSizes,
                              selectedSize: activeSize,
                              onSizeSelected: (size) {
                                setState(() {
                                  _selectedSize = size;
                                  final match = product.variants.firstWhere(
                                    (v) => v.size == size,
                                    orElse: () => product.variants.first,
                                  );
                                  _selectedVariantId = match.id;
                                });
                              },
                            ),
                            const SizedBox(height: 20),

                            // Color Selector
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Color',
                                  style: AppTypography.bodyMedium(
                                    weight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  activeVariant.colorName,
                                  style: AppTypography.caption(
                                    color: colors.primary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ColorSwatchSelector(
                              swatches: swatches,
                              selectedSwatchId: activeVariant.id,
                              onSwatchSelected: (item) {
                                // A colour is a specific variant, so the size
                                // highlight follows it.
                                final variant = product.variants.firstWhere(
                                  (v) => v.id == item.id,
                                );
                                setState(() {
                                  _selectedVariantId = variant.id;
                                  _selectedSize = variant.size;
                                });
                              },
                            ),
                            const SizedBox(height: 24),

                            // Description Section (Screen 3 Mockup)
                            Text(
                              'Description',
                              style: AppTypography.bodyMedium(
                                weight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description,
                              maxLines: _isDescriptionExpanded ? null : 3,
                              overflow: _isDescriptionExpanded
                                  ? null
                                  : TextOverflow.ellipsis,
                              style: AppTypography.body(
                                color: colors.textSecondary,
                              ).copyWith(fontSize: 13, height: 1.45),
                            ),
                            PressableScale(
                              onTap: () => setState(
                                () => _isDescriptionExpanded =
                                    !_isDescriptionExpanded,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  _isDescriptionExpanded
                                      ? 'Read Less'
                                      : 'Read More',
                                  style: AppTypography.caption(
                                    color: colors.primary,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Complimentary Perks Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.surfaceMuted,
                                borderRadius: AppRadius.cardRadius,
                                border: Border.all(
                                  color: colors.border.withOpacity(0.5),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildPerkRow(
                                    icon: Icons.local_shipping_outlined,
                                    title: 'Complimentary Express Delivery',
                                    desc:
                                        'Estimated arrival in 2–4 business days.',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPerkRow(
                                    icon: Icons.assignment_return_outlined,
                                    title:
                                        'Effortless 7-Day Returns & Exchanges',
                                    desc:
                                        'Doorstep pickup at zero cost to you.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Recommendations
                            _buildRecommendations(context, product.id),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Sticky Bottom Action Bar (Screen 3 Mockup: Add to Cart + Buy Now)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.border.withOpacity(0.6)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  // Blueprint section 26: Try-On sits right beside the
                  // purchase button and always leads back to buying.
                  child: Row(
                    children: product.isTryonEligible
                        ? [
                            Expanded(
                              child: _ActionPill(
                                label: ClothsyCopy.tryOnButton,
                                icon: Icons.auto_awesome,
                                style: _ActionPillStyle.ai,
                                onTap: () => context.push(
                                  '/tryon?productId=${product.id}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionPill(
                                label: 'Add to bag',
                                icon: Icons.shopping_bag_outlined,
                                style: _ActionPillStyle.primary,
                                onTap: () => _addToBag(product, activeVariant),
                              ),
                            ),
                          ]
                        : [
                            Expanded(
                              child: _ActionPill(
                                label: 'Add to bag',
                                icon: Icons.shopping_bag_outlined,
                                style: _ActionPillStyle.secondary,
                                onTap: () => _addToBag(product, activeVariant),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionPill(
                                label: 'Buy now',
                                style: _ActionPillStyle.primary,
                                onTap: () {
                                  ref
                                      .read(cartProvider.notifier)
                                      .addToCart(product, activeVariant);
                                  context.go('/bag');
                                },
                              ),
                            ),
                          ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addToBag(Product product, ProductVariant variant) {
    ref.read(cartProvider.notifier).addToCart(product, variant);
    ClothsySnackbar.show(
      context,
      message: '${product.title} is in your bag.',
      type: SnackbarType.success,
    );
  }

  Widget _buildPerkRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium(
                  weight: FontWeight.w600,
                ).copyWith(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: AppTypography.caption(
                  color: colors.textSecondary,
                ).copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(BuildContext context, String currentProductId) {
    final recsAsync = ref.watch(recommendationsProvider(currentProductId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You May Also Like',
          style: AppTypography.h3(color: context.colors.textPrimary),
        ),
        const SizedBox(height: 12),
        recsAsync.when(
          loading: () => const SizedBox(
            height: 290,
            child: Row(
              children: [
                Expanded(child: ProductCardSkeleton()),
                SizedBox(width: 12),
                Expanded(child: ProductCardSkeleton()),
              ],
            ),
          ),
          error: (err, _) => const SizedBox.shrink(),
          data: (products) {
            if (products.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: ProductCard.heightForWidth(175),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final rec = products[index];
                  final isWishlisted = ref.watch(
                    isProductWishlistedProvider(rec.id),
                  );

                  return SizedBox(
                    width: 175,
                    child: ProductCard(
                      id: rec.id,
                      heroTag: 'rec_${rec.id}',
                      brand: rec.brand,
                      title: rec.title,
                      price: rec.price,
                      originalPrice: rec.originalPrice,
                      imageUrl: rec.primaryImage,
                      isWishlisted: isWishlisted,
                      onTap: () => context.push('/product/${rec.id}'),
                      onWishlistToggle: () {
                        ref.read(wishlistProvider.notifier).toggleWishlist(rec);
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _openSizeGuideSheet(BuildContext context) {
    final colors = context.colors;
    ClothsyBottomSheet.show(
      context: context,
      title: 'Size Guide',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Body Measurements (Inches)',
            style: AppTypography.h3(color: colors.textPrimary),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Table(
              border: TableBorder.all(
                color: colors.border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: colors.surfaceMuted),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      child: Text(
                        'Size',
                        style: AppTypography.caption(
                          weight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      child: Text(
                        'Bust',
                        style: AppTypography.caption(
                          weight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      child: Text(
                        'Waist',
                        style: AppTypography.caption(
                          weight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      child: Text(
                        'Hips',
                        style: AppTypography.caption(
                          weight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        'XS',
                        style: AppTypography.caption(weight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '32',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '25',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '35',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        'S',
                        style: AppTypography.caption(weight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '34',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '27',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '37',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        'M',
                        style: AppTypography.caption(weight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '36',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '29',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '39',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        'L',
                        style: AppTypography.caption(weight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '38',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '31',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '41',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        'XL',
                        style: AppTypography.caption(weight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '40',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '33',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        '43',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Between sizes? Check the seller\'s fit notes and reviews, or pick the size you usually wear.',
            style: AppTypography.caption(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

enum _ActionPillStyle { primary, secondary, ai }

/// Full-width pill used in the sticky purchase bar: violet for the main
/// action, outlined violet for secondary, Try-On Coral for Clothsy AI.
class _ActionPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final _ActionPillStyle style;
  final VoidCallback onTap;

  const _ActionPill({
    required this.label,
    required this.style,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color background;
    final Color foreground;
    Border? border;
    switch (style) {
      case _ActionPillStyle.primary:
        background = colors.primary;
        foreground = colors.onPrimary;
      case _ActionPillStyle.secondary:
        background = colors.surface;
        foreground = colors.primary;
        border = Border.all(color: colors.primary, width: 1.4);
      case _ActionPillStyle.ai:
        background = colors.tryOn;
        foreground = colors.onPrimary;
    }

    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(100),
          border: border,
          boxShadow: style == _ActionPillStyle.secondary
              ? null
              : [
                  BoxShadow(
                    color: background.withOpacity(0.24),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(label, style: AppTypography.button(color: foreground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
