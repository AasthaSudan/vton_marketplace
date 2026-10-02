import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/features/orders/domain/repositories/order_repository.dart';

/// A server error: its machine code and any details.
class ServerError {
  final String code;
  final Map<String, dynamic> details;

  const ServerError(this.code, [this.details = const {}]);

  /// Reads Postgres function errors (`P0001`, message = code, details =
  /// JSON) and Edge Function errors ({error: {code, details}}).
  static ServerError from(Object error) {
    if (error is PostgrestException) {
      return ServerError(error.message, _json(error.details));
    }
    if (error is FunctionException) {
      final body = error.details;
      if (body is Map && body['error'] is Map) {
        final e = (body['error'] as Map).cast<String, dynamic>();
        return ServerError(
          e['code'] as String? ?? 'FUNCTION_ERROR',
          _json(e['details']),
        );
      }
      return ServerError(
        error.status >= 500 ? 'SERVER_ERROR' : 'FUNCTION_ERROR',
      );
    }
    return const ServerError('NETWORK_ERROR');
  }

  static Map<String, dynamic> _json(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    if (value is String && value.startsWith('{')) {
      try {
        return (jsonDecode(value) as Map).cast<String, dynamic>();
      } on FormatException {
        return const {};
      }
    }
    return const {};
  }

  /// What to tell the shopper.
  String get message {
    switch (code) {
      case 'OUT_OF_STOCK':
        final title = details['title'] ?? 'A piece in your bag';
        final size = details['size'];
        return '$title${size == null ? '' : ' in size $size'} just sold out. '
            'Remove it or pick another size.';
      case 'PRICE_CHANGED':
        return 'Prices in your bag changed. Review your bag and place the '
            'order again.';
      case 'VARIANT_UNAVAILABLE':
        return 'Something in your bag is no longer available. Review your bag.';
      case 'INVALID_QUANTITY':
        return 'You can order up to 10 of each piece.';
      case 'PIN_NOT_SERVICEABLE':
        return "We don't deliver to this PIN code yet. Choose another address.";
      case 'COD_UNAVAILABLE':
        return "Cash on delivery isn't available for this order. Please pick "
            'another way to pay.';
      case 'ADDRESS_NOT_FOUND':
        return 'Please choose a delivery address.';
      case 'COUPON_INVALID':
        return "That code isn't valid. Check it and try again.";
      case 'COUPON_EXPIRED':
        return 'That coupon has expired.';
      case 'COUPON_MIN_NOT_MET':
        return 'Add a little more to your bag to use this coupon.';
      case 'COUPON_LIMIT_REACHED':
        return "You've already used this coupon.";
      case 'NOT_CANCELLABLE':
        return 'This has already shipped, so it can no longer be cancelled.';
      case 'ORDER_AWAITING_PAYMENT':
        return 'This order is still waiting for payment.';
      case 'PAYMENT_GATEWAY_ERROR':
      case 'PAYMENTS_NOT_CONFIGURED':
        return "Online payment isn't available right now. Nothing was charged. "
            'Try cash on delivery or try again later.';
      case 'SIGNATURE_INVALID':
        return ClothsyCopy.paymentFailed;
      case 'NO_CONSENT':
        return ClothsyCopy.tryOnNeedsConsent;
      case 'NO_CREDITS':
        return ClothsyCopy.tryOnNoCredits;
      case 'NOT_ELIGIBLE':
        return ClothsyCopy.tryOnUnsupported;
      case 'TRYON_UNAVAILABLE':
      case 'TRYON_FAILED':
        return ClothsyCopy.tryOnFailed;
      case 'AUTH_REQUIRED':
        return 'Please sign in again to continue.';
      case 'NETWORK_ERROR':
        return "We couldn't reach Clothsy. Check your connection and try again.";
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  OrderException toOrderException() => OrderException(message, code: code);
}
