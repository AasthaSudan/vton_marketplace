import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/pressable_scale.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onActionTap;
  final EdgeInsets padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionText = 'See All',
    this.onActionTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.h2(color: colors.textPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.caption(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (onActionTap != null)
            PressableScale(
              onTap: onActionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionText ?? 'See All',
                      style: AppTypography.bodyMedium(
                        color: colors.primary,
                        weight: FontWeight.w600,
                      ).copyWith(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: colors.primary,
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
