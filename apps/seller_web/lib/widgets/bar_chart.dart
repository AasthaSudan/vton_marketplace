import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Simple vertical bars with a label under each and the value on hover.
class BarChart extends StatelessWidget {
  final List<({String label, double value, String tooltip})> bars;
  final double height;

  const BarChart({super.key, required this.bars, this.height = 160});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final max = bars.fold<double>(0, (m, b) => b.value > m ? b.value : m);
    // Label every bar when there is room, otherwise every few.
    final every = bars.length <= 14 ? 1 : (bars.length / 7).ceil();
    return SizedBox(
      height: height + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bars.length; i++)
            Expanded(
              child: Tooltip(
                message: bars[i].tooltip,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: max == 0
                          ? 2
                          : (bars[i].value / max * height).clamp(2, height),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: bars[i].value == 0
                            ? colors.border
                            : colors.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      child: i % every == 0
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                bars[i].label,
                                style: AppTypography.caption(
                                  color: colors.textSecondary,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
