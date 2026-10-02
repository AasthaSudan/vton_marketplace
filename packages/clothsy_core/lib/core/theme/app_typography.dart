import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Clothsy type system — Poppins on the Brand Blueprint v1.0 scale
/// (section 08): Display 32/40 · H1 24/32 · H2 18/26 · Body 14/22 ·
/// Label 13/18 · Caption 12/16 · Button 14/20.
class AppTypography {
  AppTypography._();

  static TextStyle _poppins({
    required double size,
    required double lineHeight,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      height: lineHeight / size,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// Display 32/40 Bold — campaign heroes, onboarding headlines.
  static TextStyle display({
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) {
    return _poppins(
      size: 32,
      lineHeight: 40,
      weight: weight,
      letterSpacing: -0.5,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Large editorial heading for hero moments (sizes between H1 and Display).
  static TextStyle serif({
    Color? color,
    double fontSize = 28,
    FontWeight weight = FontWeight.w700,
  }) {
    return _poppins(
      size: fontSize,
      lineHeight: fontSize * 1.25,
      weight: weight,
      letterSpacing: -0.3,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Heading 1 24/32 Bold — screen titles, brand names on storefronts.
  static TextStyle h1({Color? color, FontWeight weight = FontWeight.w700}) {
    return _poppins(
      size: 24,
      lineHeight: 32,
      weight: weight,
      letterSpacing: -0.3,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Heading 2 18/26 Bold — section titles: "Trending now".
  static TextStyle h2({Color? color, FontWeight weight = FontWeight.w700}) {
    return _poppins(
      size: 18,
      lineHeight: 26,
      weight: weight,
      letterSpacing: -0.2,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Sub-section titles and card headings.
  static TextStyle h3({Color? color, FontWeight weight = FontWeight.w600}) {
    return _poppins(
      size: 16,
      lineHeight: 22,
      weight: weight,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle bodyLarge({
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) {
    return _poppins(
      size: 16,
      lineHeight: 24,
      weight: weight,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Body 14/22 Regular — product details, descriptions, reviews.
  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) {
    return _poppins(
      size: 14,
      lineHeight: 22,
      weight: weight,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle bodyMedium({
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) {
    return _poppins(
      size: 14,
      lineHeight: 22,
      weight: weight,
      color: color ?? AppColors.textPrimary,
    );
  }

  /// Caption 12/16 Regular — delivery estimates, helper text, legal notes.
  static TextStyle caption({
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) {
    return _poppins(
      size: 12,
      lineHeight: 16,
      weight: weight,
      color: color ?? AppColors.textSecondary,
    );
  }

  /// Label 13/18 Medium — prices, chips, tabs, form labels.
  static TextStyle label({Color? color, FontWeight weight = FontWeight.w500}) {
    return _poppins(
      size: 13,
      lineHeight: 18,
      weight: weight,
      letterSpacing: 0.2,
      color: color ?? AppColors.textSecondary,
    );
  }

  /// Button 14/20 Bold — all primary and secondary actions.
  static TextStyle button({Color? color, FontWeight weight = FontWeight.w700}) {
    return _poppins(
      size: 14,
      lineHeight: 20,
      weight: weight,
      letterSpacing: 0.2,
      color: color ?? AppColors.onPrimary,
    );
  }

  static TextStyle price({Color? color, FontWeight weight = FontWeight.w600}) {
    return _poppins(
      size: 18,
      lineHeight: 24,
      weight: weight,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle strikeThrough({Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      decoration: TextDecoration.lineThrough,
      decorationColor: color ?? AppColors.strikethrough,
      color: color ?? AppColors.strikethrough,
    );
  }
}
