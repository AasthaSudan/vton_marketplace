import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import 'pressable_scale.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? icon;
  final Widget? trailingIcon;
  final double height;
  final Color? backgroundColor;
  final Color? textColor;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.trailingIcon,
    this.height = 54.0,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDisabled = onPressed == null || isLoading;

    final bgColor = isDisabled
        ? (backgroundColor ?? colors.primary).withOpacity(0.4)
        : (backgroundColor ?? colors.primary);

    final fgColor = textColor ?? colors.onPrimary;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.buttonRadius,
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: colors.primary.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: AppTypography.button(color: fgColor),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      trailingIcon!,
                    ],
                  ],
                ),
              ),
      ),
    );

    return isDisabled
        ? (isFullWidth ? SizedBox(width: double.infinity, child: content) : content)
        : PressableScale(
            onTap: onPressed,
            child: isFullWidth ? SizedBox(width: double.infinity, child: content) : content,
          );
  }
}
