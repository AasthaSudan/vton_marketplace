import 'package:clothsy_core/features/address/domain/entities/pin_serviceability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateDeliveryDate', () {
    test('counts working days and skips Sundays', () {
      // Thursday 2 Oct 2026 + 4 working days: Fri, Sat, (Sun), Mon, Tue.
      final date = estimateDeliveryDate(
        from: DateTime(2026, 10, 1, 18, 30),
        workingDays: 4,
      );
      expect(date, DateTime(2026, 10, 6));
    });

    test('never lands on a Sunday', () {
      for (var start = 1; start <= 7; start++) {
        for (var days = 1; days <= 10; days++) {
          final date = estimateDeliveryDate(
            from: DateTime(2026, 10, start),
            workingDays: days,
          );
          expect(date.weekday, isNot(DateTime.sunday));
        }
      }
    });

    test('zero days means today', () {
      expect(
        estimateDeliveryDate(from: DateTime(2026, 10, 2, 9), workingDays: 0),
        DateTime(2026, 10, 2),
      );
    });
  });
}
