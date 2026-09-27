import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../buttons/pressable_scale.dart';

class ColorSwatchItem {
  final String id;
  final String name;
  final Color color;

  const ColorSwatchItem({
    required this.id,
    required this.name,
    required this.color,
  });
}

class ColorSwatchSelector extends StatelessWidget {
  final List<ColorSwatchItem> swatches;
  final String? selectedSwatchId;
  final ValueChanged<ColorSwatchItem>? onSwatchSelected;
  final double circleSize;

  const ColorSwatchSelector({
    super.key,
    required this.swatches,
    this.selectedSwatchId,
    this.onSwatchSelected,
    this.circleSize = 36.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: swatches.map((item) {
        final isSelected = selectedSwatchId == item.id;

        return PressableScale(
          onTap: () => onSwatchSelected?.call(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? colors.primary : Colors.transparent,
                width: 2.0,
              ),
            ),
            padding: const EdgeInsets.all(3.0),
            child: Container(
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.border.withOpacity(0.5),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected && item.color.computeLuminance() > 0.8
                  ? Icon(Icons.check, size: 14, color: colors.primary)
                  : (isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null),
            ),
          ),
        );
      }).toList(),
    );
  }
}
