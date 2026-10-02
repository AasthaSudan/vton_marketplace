import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import 'pressable_scale.dart';

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? icon;
  final Widget? trailingIcon;
  final double height;
  final Color? borderColor;
  final Color? textColor;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.trailingIcon,
    this.height = 54.0,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDisabled = onPressed == null || isLoading;

    final effectiveBorderColor = isDisabled
        ? colors.border.withOpacity(0.5)
        : (borderColor ?? colors.border);

    final fgColor = isDisabled
        ? colors.textSecondary.withOpacity(0.4)
        : (textColor ?? colors.primary);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: AppRadius.buttonRadius,
        border: Border.all(color: effectiveBorderColor, width: 1.5),
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
            // Like PrimaryButton: long labels shrink to fit instead of
            // overflowing on narrow phones or with large text.
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 8)],
                    Text(text, style: AppTypography.button(color: fgColor)),
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
        ? (isFullWidth
              ? SizedBox(width: double.infinity, child: content)
              : content)
        : PressableScale(
            onTap: onPressed,
            child: isFullWidth
                ? SizedBox(width: double.infinity, child: content)
                : content,
          );
  }
}
