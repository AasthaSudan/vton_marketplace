import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyFormatter (paise → ₹)', () {
    test('formats whole rupees without decimals', () {
      expect(CurrencyFormatter.format(149900), '₹1,499');
      expect(CurrencyFormatter.format(0), '₹0');
    });

    test('shows paise only when present', () {
      expect(CurrencyFormatter.format(149950), '₹1,499.50');
      expect(CurrencyFormatter.format(1), '₹0.01');
    });

    test('uses Indian digit grouping (lakh / crore)', () {
      expect(CurrencyFormatter.format(12345600), '₹1,23,456');
      expect(CurrencyFormatter.format(1000000000), '₹1,00,00,000');
    });

    test('fromRupees converts and rounds to paise', () {
      expect(CurrencyFormatter.fromRupees(1499), 149900);
      expect(CurrencyFormatter.fromRupees(12.345), 1235);
    });
  });
}
