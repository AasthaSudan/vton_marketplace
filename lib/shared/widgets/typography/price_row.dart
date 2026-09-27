import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../badges/discount_badge.dart';

class PriceRow extends StatelessWidget {
  final num price;
  final num? originalPrice;
  final String? discountText;
  final double currentPriceFontSize;
  final bool showDiscountBadge;

  const PriceRow({
    super.key,
    required this.price,
    this.originalPrice,
    this.discountText,
    this.currentPriceFontSize = 18.0,
    this.showDiscountBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasDiscount = originalPrice != null && originalPrice! > price;

    String? calculatedDiscount = discountText;
    if (calculatedDiscount == null && hasDiscount) {
      final percentage = (((originalPrice! - price) / originalPrice!) * 100).round();
      if (percentage > 0) {
        calculatedDiscount = '$percentage% OFF';
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Text(
          CurrencyFormatter.format(price),
          style: AppTypography.price(color: colors.textPrimary).copyWith(
            fontSize: currentPriceFontSize,
          ),
        ),
        if (hasDiscount)
          Text(
            CurrencyFormatter.format(originalPrice!),
            style: AppTypography.strikeThrough(color: colors.strikethrough),
          ),
        if (showDiscountBadge && calculatedDiscount != null)
          DiscountBadge(text: calculatedDiscount),
      ],
    );
  }
}
