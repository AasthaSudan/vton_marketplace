import 'package:clothsy_core/core/constants/app_config.dart';
import 'package:clothsy_core/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('mock flavor never needs keys', () {
      const config = AppConfig(flavor: AppFlavor.mock);
      expect(config.useMockBackend, isTrue);
      expect(config.missingKeys, isEmpty);
    });

    test('dev without keys falls back to mock backend', () {
      const config = AppConfig(flavor: AppFlavor.dev);
      expect(config.useMockBackend, isTrue);
      expect(config.missingKeys, isEmpty);
    });

    test('prod without keys reports every missing value', () {
      const config = AppConfig(flavor: AppFlavor.prod);
      expect(config.useMockBackend, isFalse);
      expect(config.missingKeys, [
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        'RAZORPAY_KEY_ID',
      ]);
    });

    test('dev against a local backend may skip the Razorpay key', () {
      const config = AppConfig(
        flavor: AppFlavor.dev,
        supabaseUrl: 'http://127.0.0.1:54321',
        supabaseAnonKey: 'anon',
      );
      expect(config.useMockBackend, isFalse);
      expect(config.missingKeys, isEmpty);
      expect(config.usesRazorpay, isFalse);
    });

    test('staging still requires the Razorpay key', () {
      const config = AppConfig(
        flavor: AppFlavor.staging,
        supabaseUrl: 'https://x.supabase.co',
        supabaseAnonKey: 'anon',
      );
      expect(config.missingKeys, ['RAZORPAY_KEY_ID']);
    });

    test('Razorpay checkout runs only on Android and iOS', () {
      const config = AppConfig(
        flavor: AppFlavor.prod,
        razorpayKeyId: 'rzp_live_1',
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(config.usesRazorpay, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(config.usesRazorpay, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    test('fully configured staging uses the real backend', () {
      const config = AppConfig(
        flavor: AppFlavor.staging,
        supabaseUrl: 'https://x.supabase.co',
        supabaseAnonKey: 'anon',
        razorpayKeyId: 'rzp_test_1',
      );
      expect(config.hasBackend, isTrue);
      expect(config.useMockBackend, isFalse);
      expect(config.missingKeys, isEmpty);
    });
  });
}
