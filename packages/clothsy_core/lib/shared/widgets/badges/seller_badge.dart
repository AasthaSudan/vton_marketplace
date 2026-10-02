import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/catalog/domain/entities/seller.dart';
import '../buttons/pressable_scale.dart';

/// Round brand avatar: the logo when there is one, otherwise the brand's
/// monogram on Soft Lilac.
class SellerAvatar extends StatelessWidget {
  final Seller seller;
  final double size;

  const SellerAvatar({super.key, required this.seller, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final logo = seller.logoUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceMuted,
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: logo != null
          ? CachedNetworkImage(imageUrl: logo, fit: BoxFit.cover)
          : Text(
              seller.monogram,
              style: AppTypography.label(
                color: colors.primary,
                weight: FontWeight.w700,
              ).copyWith(fontSize: size * 0.34),
            ),
    );
  }
}

/// Small "verified" tick shown beside a brand name once Clothsy has verified
/// its business and bank details. Always paired with an accessible label.
class VerifiedBadge extends StatelessWidget {
  final double size;

  const VerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verified brand',
      child: Icon(
        Icons.verified_rounded,
        size: size,
        color: context.colors.primary,
      ),
    );
  }
}

/// "Sold by BRAND ✓" — shows who a product belongs to and opens the brand
/// storefront when tapped.
class SellerChip extends StatelessWidget {
  final Seller? seller;

  /// Used until [seller] has loaded.
  final String fallbackName;
  final VoidCallback? onTap;

  const SellerChip({
    super.key,
    required this.seller,
    required this.fallbackName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = seller;
    return PressableScale(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s != null) ...[
            SellerAvatar(seller: s, size: 24),
            const SizedBox(width: 8),
          ],
          Text(
            'Sold by ',
            style: AppTypography.caption(color: colors.textSecondary),
          ),
          Flexible(
            child: Text(
              s?.name ?? fallbackName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(
                color: colors.primary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          if (s?.isVerified ?? false) ...[
            const SizedBox(width: 4),
            const VerifiedBadge(size: 14),
          ],
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }
}
