import 'package:clothsy_core/features/cart/domain/entities/coupon.dart';
import 'package:clothsy_core/features/cart/domain/repositories/coupon_repository.dart';

/// Launch coupons for the mock flavor. The Supabase backend seeds the same
/// codes (supabase/seed/00_reference.sql) and owns them from then on.
class MockCouponRepository implements CouponRepository {
  static const Map<String, CouponRule> _coupons = {
    'CLOTHSY10': CouponRule(code: 'CLOTHSY10', percentBps: 1000),
    'WELCOME10': CouponRule(code: 'WELCOME10', percentBps: 1000),
    'FIRST15': CouponRule(code: 'FIRST15', percentBps: 1500),
    'LUXURY20': CouponRule(code: 'LUXURY20', percentBps: 2000),
  };

  @override
  Future<CouponRule> validate(String code, {required int goodsSubtotal}) async {
    final rule = _coupons[code.trim().toUpperCase()];
    if (rule == null) {
      throw const CouponException(
        'COUPON_INVALID',
        "That code isn't valid. Check it and try again.",
      );
    }
    return rule;
  }
}
