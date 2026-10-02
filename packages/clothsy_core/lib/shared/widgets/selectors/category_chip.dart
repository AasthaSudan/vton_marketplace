import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/pressable_scale.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? imageUrl;
  final bool isSelected;
  final VoidCallback? onTap;
  final double circleSize;

  const CategoryChip({
    super.key,
    required this.label,
    this.icon,
    this.imageUrl,
    this.isSelected = false,
    this.onTap,
    this.circleSize = 60.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final circleBgColor = isSelected
        ? colors.primary
        : context.colors.surfaceMuted;
    final iconColor = isSelected ? Colors.white : colors.primary;
    final textColor = isSelected ? colors.primary : colors.textSecondary;
    final fontWeight = isSelected ? FontWeight.w700 : FontWeight.w500;

    return PressableScale(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: circleBgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : colors.border.withOpacity(0.6),
                width: 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: iconColor, size: circleSize * 0.44)
                  : Text(
                      label.isNotEmpty ? label[0].toUpperCase() : '?',
                      style: AppTypography.h3(color: iconColor),
                    ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(
              color: textColor,
              weight: fontWeight,
            ).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
