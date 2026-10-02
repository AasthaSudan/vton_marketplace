import 'package:clothsy_core/features/cart/domain/entities/coupon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CouponRule.discountFor', () {
    test('percentages use integer paise, rounded half up', () {
      const ten = CouponRule(code: 'CLOTHSY10', percentBps: 1000);
      expect(ten.discountFor(1299800), 129980);
      expect(ten.discountFor(5), 1); // 0.5 paise rounds up
      expect(ten.discountFor(4), 0);
    });

    test('caps at the maximum and never exceeds the goods', () {
      const capped = CouponRule(
        code: 'BIG50',
        percentBps: 5000,
        maxDiscount: 50000,
      );
      expect(capped.discountFor(300000), 50000);
      const flat = CouponRule(code: 'FLAT500', flatAmount: 50000);
      expect(flat.discountFor(30000), 30000);
      expect(flat.discountFor(80000), 50000);
    });

    test('needs the minimum goods total', () {
      const rule = CouponRule(
        code: 'MIN999',
        percentBps: 1000,
        minSubtotal: 99900,
      );
      expect(rule.discountFor(99800), 0);
      expect(rule.discountFor(99900), 9990);
    });

    test('an empty bag gets nothing', () {
      const rule = CouponRule(code: 'X', percentBps: 1000);
      expect(rule.discountFor(0), 0);
    });
  });
}
