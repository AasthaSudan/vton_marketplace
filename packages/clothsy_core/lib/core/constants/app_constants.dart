/// Build flavors. `mock` runs entirely on in-memory mock repositories (no
/// backend, no keys) — used for UI work, demos and tests.
enum AppFlavor { mock, dev, staging, prod }

class AppConstants {
  AppConstants._();

  static const String appName = 'Clothsy';
  static const String appTagline = 'See Yourself In Every Outfit';
  static const String defaultCurrencySymbol = '\$';
  static const int defaultPageSize = 20;

  static const Duration defaultAnimationDuration = Duration(milliseconds: 250);
  static const Duration debounceDuration = Duration(milliseconds: 400);

  // Active flavor configuration
  static AppFlavor currentFlavor = AppFlavor.dev;

  static bool get isMock => currentFlavor == AppFlavor.mock;
  static bool get isDev => currentFlavor == AppFlavor.dev;
  static bool get isStaging => currentFlavor == AppFlavor.staging;
  static bool get isProd => currentFlavor == AppFlavor.prod;
}
