import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'pressable_scale.dart';

class ClothsyIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? borderColor;
  final double size;
  final bool hasShadow;

  const ClothsyIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.borderColor,
    this.size = 44.0,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PressableScale(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? colors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? colors.border.withOpacity(0.6),
            width: 1.0,
          ),
          boxShadow: hasShadow
              ? [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}
