import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
        background: AppColors.background,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: AppTypography.display(),
        headlineLarge: AppTypography.h1(),
        headlineMedium: AppTypography.h2(),
        headlineSmall: AppTypography.h3(),
        bodyLarge: AppTypography.bodyLarge(),
        bodyMedium: AppTypography.body(),
        bodySmall: AppTypography.caption(),
        labelLarge: AppTypography.label(),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.primary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      extensions: const [ClothsyColorExtension.light],
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        onPrimary: AppColors.onPrimaryDark,
        secondary: AppColors.accentDark,
        surface: AppColors.surfaceDark,
        error: AppColors.errorDark,
        background: AppColors.backgroundDark,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: AppTypography.display(color: AppColors.textPrimaryDark),
        headlineLarge: AppTypography.h1(color: AppColors.textPrimaryDark),
        headlineMedium: AppTypography.h2(color: AppColors.textPrimaryDark),
        headlineSmall: AppTypography.h3(color: AppColors.textPrimaryDark),
        bodyLarge: AppTypography.bodyLarge(color: AppColors.textPrimaryDark),
        bodyMedium: AppTypography.body(color: AppColors.textPrimaryDark),
        bodySmall: AppTypography.caption(color: AppColors.textSecondaryDark),
        labelLarge: AppTypography.label(color: AppColors.textSecondaryDark),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.primaryDark),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: const BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      extensions: const [ClothsyColorExtension.dark],
    );
  }
}
