/// The rule behind a coupon code, as validated by the coupon service.
///
/// The bag uses it to show the discount instantly while quantities change;
/// the server applies the same rule again when the order is placed, so the
/// customer is never charged on the client's word.
class CouponRule {
  final String code;

  /// Percentage in basis points (1000 = 10%), or null for a flat coupon.
  final int? percentBps;

  /// Flat amount off in paise, for flat coupons.
  final int? flatAmount;

  /// Upper limit on the discount in paise, if any.
  final int? maxDiscount;

  /// Goods total (paise) the bag must reach for the coupon to apply.
  final int minSubtotal;

  const CouponRule({
    required this.code,
    this.percentBps,
    this.flatAmount,
    this.maxDiscount,
    this.minSubtotal = 0,
  });

  /// Discount in paise for [goodsSubtotal]. Integer maths, rounded half up,
  /// capped by [maxDiscount] and never more than the goods are worth. The
  /// database's `private.coupon_discount` uses the identical formula.
  int discountFor(int goodsSubtotal) {
    if (goodsSubtotal <= 0 || goodsSubtotal < minSubtotal) return 0;
    var discount = percentBps != null
        ? (goodsSubtotal * percentBps! + 5000) ~/ 10000
        : (flatAmount ?? 0);
    if (maxDiscount != null && discount > maxDiscount!) discount = maxDiscount!;
    return discount > goodsSubtotal ? goodsSubtotal : discount;
  }
}
