import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // High-Fashion Editorial Display Serif (Mockup kicker & headlines)
  static TextStyle display({
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: 40,
      fontWeight: weight,
      height: 1.2,
      letterSpacing: -0.5,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle serif({
    Color? color,
    double fontSize = 28,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: weight,
      height: 1.25,
      letterSpacing: -0.3,
      color: color ?? AppColors.textPrimary,
    );
  }

  // Clean, Modern, Minimalist Headlines (Inter)
  static TextStyle h1({Color? color, FontWeight weight = FontWeight.w700}) {
    return GoogleFonts.inter(
      fontSize: 24,
      fontWeight: weight,
      height: 1.25,
      letterSpacing: -0.4,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle h2({Color? color, FontWeight weight = FontWeight.w700}) {
    return GoogleFonts.inter(
      fontSize: 20,
      fontWeight: weight,
      height: 1.3,
      letterSpacing: -0.3,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle h3({Color? color, FontWeight weight = FontWeight.w600}) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: weight,
      height: 1.35,
      letterSpacing: -0.2,
      color: color ?? AppColors.textPrimary,
    );
  }

  // Sans body & UI (Inter)
  static TextStyle bodyLarge({
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: weight,
      height: 1.5,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) {
    return GoogleFonts.inter(
      fontSize: 15,
      fontWeight: weight,
      height: 1.45,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle bodyMedium({
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.inter(
      fontSize: 15,
      fontWeight: weight,
      height: 1.45,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle caption({
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: 13,
      fontWeight: weight,
      height: 1.4,
      color: color ?? AppColors.textSecondary,
    );
  }

  static TextStyle label({Color? color, FontWeight weight = FontWeight.w600}) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: weight,
      height: 1.3,
      letterSpacing: 0.5,
      color: color ?? AppColors.textSecondary,
    );
  }

  static TextStyle button({Color? color, FontWeight weight = FontWeight.w600}) {
    return GoogleFonts.inter(
      fontSize: 15,
      fontWeight: weight,
      height: 1.2,
      letterSpacing: 0.2,
      color: color ?? AppColors.onPrimary,
    );
  }

  static TextStyle price({Color? color, FontWeight weight = FontWeight.w700}) {
    return GoogleFonts.inter(
      fontSize: 18,
      fontWeight: weight,
      height: 1.2,
      letterSpacing: -0.2,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle strikeThrough({Color? color}) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      decoration: TextDecoration.lineThrough,
      decorationColor: color ?? AppColors.strikethrough,
      color: color ?? AppColors.strikethrough,
    );
  }
}
