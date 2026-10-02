import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/primary_button.dart';

class EmptyStateView extends StatelessWidget {
  final Widget? illustration;
  final IconData? icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const EmptyStateView({
    super.key,
    this.illustration,
    this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (illustration != null)
              illustration!
            else
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? Icons.shopping_bag_outlined,
                  size: 42,
                  color: colors.primary.withOpacity(0.6),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h2(color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body(color: colors.textSecondary),
            ),
            if (actionText != null && onActionPressed != null) ...[
              const SizedBox(height: 28),
              PrimaryButton(
                text: actionText!,
                onPressed: onActionPressed,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
