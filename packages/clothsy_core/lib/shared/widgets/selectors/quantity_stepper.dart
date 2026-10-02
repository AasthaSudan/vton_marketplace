import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/pressable_scale.dart';

class QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;
  final double height;

  const QuantityStepper({
    super.key,
    required this.value,
    this.onChanged,
    this.min = 1,
    this.max = 99,
    this.height = 38.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canDecrement = value > min;
    final canIncrement = value < max;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: colors.border.withOpacity(0.6), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PressableScale(
            onTap: canDecrement ? () => onChanged?.call(value - 1) : null,
            child: Container(
              width: height - 8,
              height: height - 8,
              decoration: BoxDecoration(
                color: canDecrement ? colors.surface : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.remove_rounded,
                size: 16,
                color: canDecrement
                    ? colors.primary
                    : colors.textSecondary.withOpacity(0.3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '$value',
              style: AppTypography.bodyMedium(
                color: colors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          PressableScale(
            onTap: canIncrement ? () => onChanged?.call(value + 1) : null,
            child: Container(
              width: height - 8,
              height: height - 8,
              decoration: BoxDecoration(
                color: canIncrement ? colors.surface : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 16,
                color: canIncrement
                    ? colors.primary
                    : colors.textSecondary.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
