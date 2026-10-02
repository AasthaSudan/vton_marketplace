/// Splits an amount of paise across weights without losing or inventing a
/// single paisa.
///
/// Used to spread an order-level coupon discount over seller orders so that
/// each seller order has an exact refundable total and the parts always add
/// back up to the whole. Largest-remainder method: every share is floored, then
/// the leftover paise go to the shares with the biggest fractional parts (ties
/// go to the earlier share).
///
/// `splitProportionally(1000, [1, 1, 1])` -> `[334, 333, 333]`
List<int> splitProportionally(int amount, List<int> weights) {
  if (weights.isEmpty) return const [];
  if (amount < 0) {
    return splitProportionally(-amount, weights).map((v) => -v).toList();
  }
  final totalWeight = weights.fold<int>(0, (sum, w) => sum + w);
  if (totalWeight <= 0 || amount == 0) {
    return List<int>.filled(weights.length, 0);
  }

  final shares = <int>[];
  final remainders = <int>[];
  for (final w in weights) {
    final scaled = amount * w;
    shares.add(scaled ~/ totalWeight);
    remainders.add(scaled % totalWeight);
  }

  var leftover = amount - shares.fold<int>(0, (sum, s) => sum + s);
  final order = List<int>.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final byRemainder = remainders[b].compareTo(remainders[a]);
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  for (final i in order) {
    if (leftover == 0) break;
    shares[i] += 1;
    leftover -= 1;
  }
  return shares;
}
