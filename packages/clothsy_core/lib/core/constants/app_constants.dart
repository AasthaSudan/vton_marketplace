/// Build flavors. `mock` runs entirely on in-memory mock repositories (no
/// backend, no keys) — used for UI work, demos and tests.
enum AppFlavor { mock, dev, staging, prod }

class AppConstants {
  AppConstants._();

  static const String appName = 'Clothsy';
  static const String appTagline = 'See it on you.';
  static const String defaultCurrencySymbol = '₹';
  static const int defaultPageSize = 20;

  /// Largest order (paise) that may be paid cash on delivery. PLACEHOLDER
  /// (₹10,000) until the COD policy is decided — Blueprint: "COD limits" to
  /// manage refused deliveries. The server applies its own limit too.
  static const int codMaxOrderValue = 1000000;

  /// Most units of one piece in a single order (the server enforces it too).
  static const int maxQuantityPerLine = 10;

  static const Duration defaultAnimationDuration = Duration(milliseconds: 250);
  static const Duration debounceDuration = Duration(milliseconds: 400);

  // Active flavor configuration
  static AppFlavor currentFlavor = AppFlavor.dev;

  static bool get isMock => currentFlavor == AppFlavor.mock;
  static bool get isDev => currentFlavor == AppFlavor.dev;
  static bool get isStaging => currentFlavor == AppFlavor.staging;
  static bool get isProd => currentFlavor == AppFlavor.prod;
}
