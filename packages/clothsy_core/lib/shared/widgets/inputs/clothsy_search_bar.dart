import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/pressable_scale.dart';

class ClothsySearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onTap;
  final bool readOnly;
  final String hintText;
  final bool showFilterButton;
  final bool autoFocus;

  const ClothsySearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.onFilterTap,
    this.onTap,
    this.readOnly = false,
    this.hintText = 'Search luxury fashion, dresses, styles...',
    this.showFilterButton = true,
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.buttonRadius,
        border: Border.all(color: colors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.search_rounded, color: colors.textSecondary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              autofocus: autoFocus,
              onTap: onTap,
              onChanged: onChanged,
              style: AppTypography.body(color: colors.textPrimary),
              cursorColor: colors.primary,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTypography.body(
                  color: colors.textSecondary.withOpacity(0.7),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (showFilterButton) ...[
            Container(height: 24, width: 1, color: colors.border),
            PressableScale(
              onTap: onFilterTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.tune_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
            ),
          ] else
            const SizedBox(width: 16),
        ],
      ),
    );
  }
}
