import 'package:flutter/foundation.dart';
import 'app_constants.dart';

/// Runtime configuration injected at build time — never hard-code keys.
///
/// ```bash
/// flutter run -t lib/main_dev.dart --dart-define-from-file=config/dev.json
/// ```
///
/// Only public client values belong here (Supabase anon key, Razorpay key id).
/// Secrets such as the Razorpay key secret or the FabricVTON API key live only
/// in Supabase Edge Function environment variables.
class AppConfig {
  final AppFlavor flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String razorpayKeyId;

  const AppConfig({
    required this.flavor,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.razorpayKeyId = '',
  });

  factory AppConfig.fromEnvironment(AppFlavor flavor) {
    return AppConfig(
      flavor: flavor,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      razorpayKeyId: const String.fromEnvironment('RAZORPAY_KEY_ID'),
    );
  }

  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Mock repositories are used for the mock flavor, and as a safe fallback
  /// for dev builds started without a config file.
  bool get useMockBackend =>
      flavor == AppFlavor.mock || (flavor == AppFlavor.dev && !hasBackend);

  /// Opens the real Razorpay checkout sheet. Needs a key id, and the
  /// Razorpay SDK only exists on Android and iOS; everywhere else payments go
  /// through the mock gateway against the server's mock provider.
  bool get usesRazorpay =>
      razorpayKeyId.isNotEmpty &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Names of required values that are missing for this flavor. Dev builds
  /// may run without a Razorpay key (local backend with mock payments);
  /// staging and prod may not.
  List<String> get missingKeys {
    if (useMockBackend) return const [];
    return [
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
      if (razorpayKeyId.isEmpty && flavor != AppFlavor.dev) 'RAZORPAY_KEY_ID',
    ];
  }
}
