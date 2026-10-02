import 'package:flutter/material.dart';

/// Design tokens for Clothsy Marketplace.
/// Palette from the Product & Brand Blueprint v1.0 (section 07): Clothsy Violet
/// for key actions, Deep Ink for text, Soft Lilac for calm surfaces and
/// Try-On Coral reserved for Clothsy AI moments.
/// Balance: white 60% · lilac 22% · violet 10% · ink 6% · accents 2%.
class AppColors {
  AppColors._();

  // Brand
  static const Color clothsyViolet = Color(0xFF5C25FC);
  static const Color deepInk = Color(0xFF14102B);
  static const Color softLilac = Color(0xFFF1ECFF);
  static const Color lilacMid = Color(0xFFD9CCFF);
  static const Color tryOnCoral = Color(0xFFFF4F7B);
  static const Color successMint = Color(0xFF0FA67A);
  static const Color alertAmber = Color(0xFFF08C00);
  static const Color mutedGrey = Color(0xFF6B6880);

  // Core Light Palette
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = softLilac;
  static const Color primary = clothsyViolet;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color accent = tryOnCoral;
  static const Color accentSoft = softLilac;
  static const Color textPrimary = deepInk;
  static const Color textSecondary = mutedGrey;
  static const Color strikethrough = Color(0xFFA3A1B3);
  static const Color border = Color(0xFFE7E3F3);
  static const Color success = successMint;
  static const Color error = Color(0xFFD63A3A);
  static const Color warning = alertAmber;
  static const Color rating = Color(0xFFF2B63C);
  static const Color tryOn = tryOnCoral;
  static const Color tryOnSoft = Color(0xFFFFE8EE);

  // Dark Palette equivalents (Deep Ink surfaces)
  static const Color backgroundDark = deepInk;
  static const Color surfaceDark = Color(0xFF1E1940);
  static const Color surfaceMutedDark = Color(0xFF2A2452);
  static const Color primaryDark = Color(0xFF9B7BFF);
  static const Color onPrimaryDark = deepInk;
  static const Color accentDark = Color(0xFFFF6F93);
  static const Color accentSoftDark = Color(0xFF2A2452);
  static const Color textPrimaryDark = Color(0xFFF5F3FF);
  static const Color textSecondaryDark = Color(0xFFA9A5C0);
  static const Color strikethroughDark = Color(0xFF77738F);
  static const Color borderDark = Color(0xFF332C5E);
  static const Color successDark = Color(0xFF2EC497);
  static const Color errorDark = Color(0xFFEF6461);
  static const Color warningDark = Color(0xFFFFA733);
  static const Color ratingDark = Color(0xFFFFC95C);
  static const Color tryOnDark = Color(0xFFFF6F93);
  static const Color tryOnSoftDark = Color(0xFF3A1F35);

  // Glass / Shading
  static const Color shadow = Color(0x0F14102B);
  static const Color overlay = Color(0x6614102B);
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
  final Color warning;
  final Color tryOn;
  final Color tryOnSoft;

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
    required this.warning,
    required this.tryOn,
    required this.tryOnSoft,
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
    warning: AppColors.warning,
    tryOn: AppColors.tryOn,
    tryOnSoft: AppColors.tryOnSoft,
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
    warning: AppColors.warningDark,
    tryOn: AppColors.tryOnDark,
    tryOnSoft: AppColors.tryOnSoftDark,
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
    Color? warning,
    Color? tryOn,
    Color? tryOnSoft,
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
      warning: warning ?? this.warning,
      tryOn: tryOn ?? this.tryOn,
      tryOnSoft: tryOnSoft ?? this.tryOnSoft,
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
      warning: Color.lerp(warning, other.warning, t)!,
      tryOn: Color.lerp(tryOn, other.tryOn, t)!,
      tryOnSoft: Color.lerp(tryOnSoft, other.tryOnSoft, t)!,
    );
  }
}

extension BuildContextColors on BuildContext {
  ClothsyColorExtension get colors =>
      Theme.of(this).extension<ClothsyColorExtension>() ??
      ClothsyColorExtension.light;
}
