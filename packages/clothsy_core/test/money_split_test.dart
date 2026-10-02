import 'package:clothsy_core/core/utils/money_split.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitProportionally', () {
    test('spreads leftover paise by largest remainder, ties to the first', () {
      expect(splitProportionally(1000, [1, 1, 1]), [334, 333, 333]);
      expect(splitProportionally(10, [1, 1, 1]), [4, 3, 3]);
    });

    test('weights by seller subtotal (₹500 coupon over two sellers)', () {
      // ₹7,999 + ₹4,999 bag: the paisa left after flooring goes to the share
      // with the bigger fractional part.
      expect(splitProportionally(50000, [799900, 499900]), [30770, 19230]);
    });

    test('exact splits need no adjustment', () {
      expect(splitProportionally(100, [3, 3, 3, 1]), [30, 30, 30, 10]);
    });

    test('parts always add back up to the whole', () {
      const cases = <(int, List<int>)>[
        (1, [1, 1, 1]),
        (99999, [3, 7, 11, 13]),
        (129980, [1299800]),
        (7, [1000000, 1, 1]),
      ];
      for (final (amount, weights) in cases) {
        final shares = splitProportionally(amount, weights);
        expect(shares.length, weights.length);
        expect(shares.fold<int>(0, (s, v) => s + v), amount);
        expect(shares.every((s) => s >= 0), isTrue);
      }
    });

    test('negative amounts mirror the positive split', () {
      expect(splitProportionally(-1000, [1, 1, 1]), [-334, -333, -333]);
    });

    test('zero amount, zero weights and no weights', () {
      expect(splitProportionally(0, [5, 5]), [0, 0]);
      expect(splitProportionally(500, [0, 0]), [0, 0]);
      expect(splitProportionally(500, []), isEmpty);
    });
  });
}
