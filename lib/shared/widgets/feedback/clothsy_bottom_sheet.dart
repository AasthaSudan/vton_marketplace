import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/clothsy_icon_button.dart';

class ClothsyBottomSheet {
  ClothsyBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? subtitle,
    bool isScrollControlled = true,
    bool showCloseButton = true,
  }) {
    final colors = context.colors;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheetRadius,
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Header if title provided
                if (title != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTypography.h2(color: colors.textPrimary),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: AppTypography.caption(color: colors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (showCloseButton)
                          ClothsyIconButton(
                            size: 36,
                            icon: Icon(Icons.close_rounded, size: 18, color: colors.primary),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                      ],
                    ),
                  ),
                  Divider(color: colors.border.withOpacity(0.5)),
                ],
                // Content
                Flexible(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}
