import 'package:flutter/material.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_bottom_sheet.dart';

/// A size chart for the kind of product: body measurements for clothing,
/// UK / EU sizes for footwear, none for bags and one-size accessories.
class SizeChart {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  const SizeChart(this.title, this.columns, this.rows);

  static const _apparel = SizeChart(
    'Body measurements (inches)',
    ['Size', 'Bust', 'Waist', 'Hips'],
    [
      ['XS', '32', '25', '35'],
      ['S', '34', '27', '37'],
      ['M', '36', '29', '39'],
      ['L', '38', '31', '41'],
      ['XL', '40', '33', '43'],
      ['XXL', '42', '35', '45'],
    ],
  );

  static const _footwear = SizeChart(
    'Footwear sizes',
    ['UK', 'EU', 'Foot length (cm)'],
    [
      ['3', '36', '22.5'],
      ['4', '37', '23.5'],
      ['5', '38', '24.0'],
      ['6', '39', '25.0'],
      ['7', '40', '25.5'],
      ['8', '41', '26.5'],
    ],
  );

  /// The chart for [product], or null when sizing does not apply.
  static SizeChart? forProduct(Product product) {
    final text = '${product.category} ${product.tags.join(' ')}'.toLowerCase();
    if (text.contains('bag') || text.contains('tote')) return null;
    if (product.availableSizes.length <= 1) return null;
    if (text.contains('shoe') || text.contains('heel')) return _footwear;
    return _apparel;
  }

  Future<void> show(BuildContext context) {
    final colors = context.colors;
    Widget cell(String text, {bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: AppTypography.caption(
          color: header ? colors.textPrimary : colors.textSecondary,
          weight: header ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );

    return ClothsyBottomSheet.show(
      context: context,
      title: 'Size guide',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h3(color: colors.textPrimary)),
          const SizedBox(height: 14),
          Table(
            border: TableBorder.all(
              color: colors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: colors.surfaceMuted),
                children: [for (final c in columns) cell(c, header: true)],
              ),
              for (final row in rows)
                TableRow(children: [for (final c in row) cell(c)]),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Between sizes? Check the seller's fit notes and reviews, or pick "
            'the size you usually wear.',
            style: AppTypography.caption(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
