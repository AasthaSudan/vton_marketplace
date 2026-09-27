import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

enum SnackbarType { success, error, info }

class ClothsySnackbar {
  ClothsySnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final colors = context.colors;

    Color bg;
    IconData icon;
    Color fg = Colors.white;

    switch (type) {
      case SnackbarType.success:
        bg = colors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case SnackbarType.error:
        bg = colors.error;
        icon = Icons.error_outline_rounded;
        break;
      case SnackbarType.info:
        bg = colors.primary;
        icon = Icons.info_outline_rounded;
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        action: action,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.cardRadius,
            boxShadow: [
              BoxShadow(
                color: bg.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.body(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
