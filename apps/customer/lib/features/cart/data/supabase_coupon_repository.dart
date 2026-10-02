import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clothsy_core/features/cart/domain/entities/coupon.dart';
import 'package:clothsy_core/features/cart/domain/repositories/coupon_repository.dart';
import '../../../core/supabase/supabase_errors.dart';

/// Coupons are validated on the server (validate_coupon), which returns the
/// rule so the bag can show the discount; place_order checks it again.
class SupabaseCouponRepository implements CouponRepository {
  final SupabaseClient _client;

  SupabaseCouponRepository(this._client);

  @override
  Future<CouponRule> validate(String code, {required int goodsSubtotal}) async {
    final json =
        await _client.rpc(
              'validate_coupon',
              params: {'p_code': code, 'p_goods_subtotal': goodsSubtotal},
            )
            as Map;
    if (json['valid'] != true) {
      final reason = json['reason'] as String? ?? 'COUPON_INVALID';
      throw CouponException(reason, ServerError(reason).message);
    }
    final rule = (json['rule'] as Map).cast<String, dynamic>();
    return CouponRule(
      code: rule['code'] as String,
      percentBps: (rule['percent_bps'] as num?)?.toInt(),
      flatAmount: (rule['flat_amount'] as num?)?.toInt(),
      maxDiscount: (rule['max_discount'] as num?)?.toInt(),
      minSubtotal: (rule['min_subtotal'] as num?)?.toInt() ?? 0,
    );
  }
}
