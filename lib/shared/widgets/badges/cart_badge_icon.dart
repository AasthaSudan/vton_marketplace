import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/pressable_scale.dart';

class CartBadgeIcon extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  final Color? iconColor;
  final double size;

  const CartBadgeIcon({
    super.key,
    this.count = 0,
    this.onTap,
    this.iconColor,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PressableScale(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: size,
              color: iconColor ?? colors.primary,
            ),
          ),
          if (count > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: AppTypography.label(
                      color: colors.onPrimary,
                      weight: FontWeight.w700,
                    ).copyWith(fontSize: 9, height: 1.0),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
