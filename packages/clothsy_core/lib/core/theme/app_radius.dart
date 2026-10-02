import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double chip = 12.0;
  static const double card = 20.0;
  static const double banner = 20.0;
  static const double button = 28.0;
  static const double circle = 999.0;

  // BorderRadius helpers
  static final BorderRadius chipRadius = BorderRadius.circular(chip);
  static final BorderRadius cardRadius = BorderRadius.circular(card);
  static final BorderRadius bannerRadius = BorderRadius.circular(banner);
  static final BorderRadius buttonRadius = BorderRadius.circular(button);
  static final BorderRadius circleRadius = BorderRadius.circular(circle);
  static const BorderRadius bottomSheetRadius = BorderRadius.only(
    topLeft: Radius.circular(24.0),
    topRight: Radius.circular(24.0),
  );
}
