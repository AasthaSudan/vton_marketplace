import 'package:clothsy_core/core/constants/app_config.dart';
import 'package:clothsy_core/core/constants/app_constants.dart';
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
