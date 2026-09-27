import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class RatingRow extends StatelessWidget {
  final double rating;
  final int? reviewCount;
  final double starSize;

  const RatingRow({
    super.key,
    required this.rating,
    this.reviewCount,
    this.starSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.star_rounded, size: starSize, color: colors.rating),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: AppTypography.caption(
            color: colors.textPrimary,
            weight: FontWeight.w600,
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: AppTypography.caption(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}
