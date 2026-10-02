import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class DiscountBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsets padding;

  const DiscountBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.accentSoft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.label(
          color: textColor ?? colors.primary,
          weight: FontWeight.w700,
        ).copyWith(fontSize: 10, letterSpacing: 0.6),
      ),
    );
  }
}
