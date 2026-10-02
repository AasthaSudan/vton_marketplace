import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/pressable_scale.dart';

class PromoBanner extends StatelessWidget {
  final String? kicker;
  final String headline;
  final String subtitle;
  final String ctaText;
  final String? imageUrl;
  final VoidCallback? onCtaPressed;
  final int totalDots;
  final int activeDotIndex;
  final Color? backgroundColor;

  const PromoBanner({
    super.key,
    this.kicker,
    required this.headline,
    required this.subtitle,
    this.ctaText = 'Shop Now',
    this.imageUrl,
    this.onCtaPressed,
    this.totalDots = 3,
    this.activeDotIndex = 0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cardBg = backgroundColor ?? colors.primary;

    return Container(
      height: 195,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppRadius.bannerRadius,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background subtle artistic pattern/circle
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withOpacity(0.12),
              ),
            ),
          ),
          // Content Row
          Row(
            children: [
              // Left text column
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (kicker != null ||
                              headline.contains('New Styles')) ...[
                            Text(
                              kicker ?? 'New Season',
                              style: AppTypography.caption(
                                color: colors.onPrimary.withOpacity(0.75),
                                weight: FontWeight.w600,
                              ).copyWith(fontSize: 11, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 3),
                          ],
                          Text(
                            headline.replaceAll('New Season\n', ''),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTypography.display(
                                  color: colors.onPrimary,
                                ).copyWith(
                                  fontSize: 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(
                              color: colors.onPrimary.withOpacity(0.75),
                            ).copyWith(fontSize: 11, height: 1.3),
                          ),
                        ],
                      ),
                      // Pill CTA Button
                      PressableScale(
                        onTap: onCtaPressed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            ctaText,
                            style: AppTypography.label(
                              color: cardBg,
                              weight: FontWeight.w700,
                            ).copyWith(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right image column
              if (imageUrl != null)
                Expanded(
                  flex: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        height: double.infinity,
                        placeholder: (context, url) =>
                            Container(color: colors.primary.withOpacity(0.2)),
                        errorWidget: (context, url, error) =>
                            const SizedBox.shrink(),
                      ),
                      // Subtle gradient overlay from card to image
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [cardBg, cardBg.withOpacity(0.0)],
                            ),
                          ),
                        ),
                      ),
                      // Mockup Sparkle ✦ in top right corner
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: colors.accent.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // Carousel dots indicator
          if (totalDots > 1)
            Positioned(
              bottom: 12,
              right: 18,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(totalDots, (index) {
                  final isActive = index == activeDotIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: isActive ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
