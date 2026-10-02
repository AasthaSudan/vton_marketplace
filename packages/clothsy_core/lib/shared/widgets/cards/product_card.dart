import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../badges/discount_badge.dart';
import '../buttons/clothsy_icon_button.dart';
import '../buttons/pressable_scale.dart';
import '../typography/price_row.dart';

class ProductCard extends StatelessWidget {
  final String id;
  final String title;
  final String? brand;
  final int price;
  final int? originalPrice;
  final String imageUrl;
  final bool isWishlisted;
  final VoidCallback? onTap;
  final VoidCallback? onWishlistToggle;
  final double? width;
  final bool isTriedOn;
  final String? heroTag;

  const ProductCard({
    super.key,
    required this.id,
    required this.title,
    this.brand,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    this.isWishlisted = false,
    this.onTap,
    this.onWishlistToggle,
    this.width,
    this.isTriedOn = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasDiscount = originalPrice != null && originalPrice! > price;
    String? discountStr;
    if (hasDiscount) {
      final pct = (((originalPrice! - price) / originalPrice!) * 100).round();
      if (pct > 0) discountStr = '$pct% OFF';
    }

    return PressableScale(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: colors.border.withOpacity(0.6), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Stack
            AspectRatio(
              aspectRatio: 0.94,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  heroTag != null
                      ? Hero(
                          tag: heroTag!,
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: colors.surfaceMuted,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.accent,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: colors.surfaceMuted,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: colors.textSecondary.withOpacity(0.5),
                              ),
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: colors.surfaceMuted,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.accent,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colors.surfaceMuted,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colors.textSecondary.withOpacity(0.5),
                            ),
                          ),
                        ),
                  // Gradient tint for readability
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Discount badge
                  if (discountStr != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: DiscountBadge(text: discountStr),
                    ),
                  // Wishlist button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: ClothsyIconButton(
                      size: 34,
                      backgroundColor: colors.surface.withOpacity(0.9),
                      borderColor: Colors.transparent,
                      icon: Icon(
                        isWishlisted
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        color: isWishlisted ? colors.error : colors.primary,
                        size: 18,
                      ),
                      onPressed: onWishlistToggle,
                    ),
                  ),
                  // Tried On badge (reserved for Phase 4)
                  if (isTriedOn)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 10,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'TRIED ON',
                              style: AppTypography.label(
                                color: colors.onPrimary,
                              ).copyWith(fontSize: 9, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product info
            Padding(
              padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (brand != null) ...[
                    Text(
                      brand!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        color: colors.textSecondary,
                        weight: FontWeight.w600,
                      ).copyWith(fontSize: 10, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(
                      color: colors.textPrimary,
                      weight: FontWeight.w600,
                    ).copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  PriceRow(
                    price: price,
                    originalPrice: originalPrice,
                    showDiscountBadge: false,
                    currentPriceFontSize: 15,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
