import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

class ClothsyTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool isPassword;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const ClothsyTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<ClothsyTextField> createState() => _ClothsyTextFieldState();
}

class _ClothsyTextFieldState extends State<ClothsyTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.caption(
              color: colors.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          obscureText: widget.isPassword && _obscureText,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          style: AppTypography.body(color: colors.textPrimary),
          cursorColor: colors.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTypography.body(color: colors.textSecondary.withOpacity(0.6)),
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: widget.prefixIcon,
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  )
                : widget.suffixIcon,
            filled: true,
            fillColor: widget.enabled ? colors.surface : colors.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: AppRadius.cardRadius,
              borderSide: BorderSide(color: colors.border, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.cardRadius,
              borderSide: BorderSide(color: colors.border, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.cardRadius,
              borderSide: BorderSide(color: colors.primary, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.cardRadius,
              borderSide: BorderSide(color: colors.error, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.cardRadius,
              borderSide: BorderSide(color: colors.error, width: 1.8),
            ),
            errorText: widget.errorText,
            errorStyle: AppTypography.caption(color: colors.error).copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
