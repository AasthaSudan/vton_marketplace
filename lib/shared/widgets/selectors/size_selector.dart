import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/pressable_scale.dart';

class SizeSelector extends StatelessWidget {
  final List<String> sizes;
  final String? selectedSize;
  final ValueChanged<String>? onSizeSelected;
  final List<String> unavailableSizes;

  const SizeSelector({
    super.key,
    required this.sizes,
    this.selectedSize,
    this.onSizeSelected,
    this.unavailableSizes = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: sizes.map((size) {
        final isSelected = selectedSize == size;
        final isUnavailable = unavailableSizes.contains(size);

        final isPill = size.length > 2;

        return PressableScale(
          onTap: isUnavailable ? null : () => onSizeSelected?.call(size),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isPill ? 14 : 0,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: isSelected
                  ? colors.primary
                  : (isUnavailable ? colors.surfaceMuted.withOpacity(0.5) : colors.surface),
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : (isUnavailable ? colors.border.withOpacity(0.4) : colors.border),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  size,
                  maxLines: 1,
                  style: AppTypography.button(
                    color: isSelected
                        ? colors.onPrimary
                        : (isUnavailable ? colors.textSecondary.withOpacity(0.4) : colors.textPrimary),
                    weight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ).copyWith(fontSize: isPill ? 12 : 14),
                ),
                if (isUnavailable)
                  Transform.rotate(
                    angle: -0.785,
                    child: Container(
                      width: 32,
                      height: 1.5,
                      color: colors.textSecondary.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
