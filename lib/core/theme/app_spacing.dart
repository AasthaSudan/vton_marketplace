import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double screenSide = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // EdgeInsets helpers
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: screenSide);
  static const EdgeInsets screenPaddingAll = EdgeInsets.all(screenSide);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets bannerPadding = EdgeInsets.all(screenSide);
}
