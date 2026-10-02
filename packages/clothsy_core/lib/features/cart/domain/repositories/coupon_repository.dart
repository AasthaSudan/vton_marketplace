import '../entities/coupon.dart';

/// Why a coupon was refused, with a message ready to show in the bag.
class CouponException implements Exception {
  /// Machine-readable reason, e.g. `COUPON_INVALID`, `COUPON_MIN_NOT_MET`.
  final String code;
  final String message;

  const CouponException(this.code, this.message);

  @override
  String toString() => message;
}

abstract class CouponRepository {
  /// Checks [code] against a bag whose goods are worth [goodsSubtotal] paise.
  /// Throws [CouponException] when it cannot be used.
  Future<CouponRule> validate(String code, {required int goodsSubtotal});
}
