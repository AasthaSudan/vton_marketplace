import 'package:flutter/material.dart';

/// Design tokens for Clothsy Shop App.
/// Pure brand colors matching clothsyai.fabricvton.com and the editorial style.
class AppColors {
  AppColors._();

  // Core Light Palette
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF2EDF7);
  static const Color primary = Color(0xFF2B1E3F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFB9A6E0);
  static const Color accentSoft = Color(0xFFE7DFF6);
  static const Color textPrimary = Color(0xFF1A1523);
  static const Color textSecondary = Color(0xFF6E6878);
  static const Color strikethrough = Color(0xFFA39FAB);
  static const Color border = Color(0xFFE6E1EA);
  static const Color success = Color(0xFF2E7D5B);
  static const Color error = Color(0xFFC2413B);
  static const Color rating = Color(0xFFF2B63C);

  // Dark Palette equivalents
  static const Color backgroundDark = Color(0xFF131018);
  static const Color surfaceDark = Color(0xFF1F1A28);
  static const Color surfaceMutedDark = Color(0xFF282234);
  static const Color primaryDark = Color(0xFFD6C8F5);
  static const Color onPrimaryDark = Color(0xFF1A1326);
  static const Color accentDark = Color(0xFFC6B5E8);
  static const Color accentSoftDark = Color(0xFF382E4B);
  static const Color textPrimaryDark = Color(0xFFF7F5F9);
  static const Color textSecondaryDark = Color(0xFFA9A3B5);
  static const Color strikethroughDark = Color(0xFF756E82);
  static const Color borderDark = Color(0xFF362E44);
  static const Color successDark = Color(0xFF48A57A);
  static const Color errorDark = Color(0xFFE05D56);
  static const Color ratingDark = Color(0xFFFFC95C);

  // Glass / Shading
  static const Color shadow = Color(0x0C2B1E3F);
  static const Color overlay = Color(0x661A1523);
}

/// ThemeExtension to access custom semantic colors in context cleanly
class ClothsyColorExtension extends ThemeExtension<ClothsyColorExtension> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color accentSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color strikethrough;
  final Color border;
  final Color success;
  final Color error;
  final Color rating;

  const ClothsyColorExtension({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.strikethrough,
    required this.border,
    required this.success,
    required this.error,
    required this.rating,
  });

  static const light = ClothsyColorExtension(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceMuted: AppColors.surfaceMuted,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    accent: AppColors.accent,
    accentSoft: AppColors.accentSoft,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    strikethrough: AppColors.strikethrough,
    border: AppColors.border,
    success: AppColors.success,
    error: AppColors.error,
    rating: AppColors.rating,
  );

  static const dark = ClothsyColorExtension(
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    surfaceMuted: AppColors.surfaceMutedDark,
    primary: AppColors.primaryDark,
    onPrimary: AppColors.onPrimaryDark,
    accent: AppColors.accentDark,
    accentSoft: AppColors.accentSoftDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    strikethrough: AppColors.strikethroughDark,
    border: AppColors.borderDark,
    success: AppColors.successDark,
    error: AppColors.errorDark,
    rating: AppColors.ratingDark,
  );

  @override
  ClothsyColorExtension copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? accentSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? strikethrough,
    Color? border,
    Color? success,
    Color? error,
    Color? rating,
  }) {
    return ClothsyColorExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      strikethrough: strikethrough ?? this.strikethrough,
      border: border ?? this.border,
      success: success ?? this.success,
      error: error ?? this.error,
      rating: rating ?? this.rating,
    );
  }

  @override
  ClothsyColorExtension lerp(
    covariant ThemeExtension<ClothsyColorExtension>? other,
    double t,
  ) {
    if (other is! ClothsyColorExtension) return this;
    return ClothsyColorExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      strikethrough: Color.lerp(strikethrough, other.strikethrough, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      rating: Color.lerp(rating, other.rating, t)!,
    );
  }
}

extension BuildContextColors on BuildContext {
  ClothsyColorExtension get colors =>
      Theme.of(this).extension<ClothsyColorExtension>() ??
      ClothsyColorExtension.light;
}
