import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';

/// Razorpay checkout (UPI, cards, net banking, wallets) on Android and iOS.
/// It only collects the payment; Clothsy's verify-payment function and the
/// webhook decide whether the order is paid.
class RazorpayPaymentGateway implements PaymentGateway {
  final String keyId;
  final Razorpay _razorpay = Razorpay();
  Completer<PaymentResult>? _pending;

  RazorpayPaymentGateway(this.keyId) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      _finish(
        PaymentSuccess(
          paymentRef: r.paymentId ?? '',
          signature: r.signature,
          gatewayOrderId: r.orderId,
        ),
      );
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      _finish(
        r.code == Razorpay.PAYMENT_CANCELLED
            ? const PaymentCancelled()
            : PaymentFailure(r.message ?? 'Payment failed'),
      );
    });
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      _finish(
        PaymentFailure(
          'Finish paying in ${r.walletName ?? 'your wallet app'}; we will confirm it shortly.',
        ),
      );
    });
  }

  void _finish(PaymentResult result) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(result);
  }

  static String _method(PaymentMethod method) => switch (method) {
    PaymentMethod.upi => 'upi',
    PaymentMethod.card => 'card',
    PaymentMethod.netBanking => 'netbanking',
    PaymentMethod.cashOnDelivery => 'upi',
  };

  @override
  Future<PaymentResult> pay(PaymentRequest request) {
    final intent = request.intent;
    if (intent == null) {
      return Future.value(
        const PaymentFailure('Payment is not ready for this order.'),
      );
    }
    _pending?.complete(const PaymentCancelled());
    final completer = Completer<PaymentResult>();
    _pending = completer;
    _razorpay.open({
      'key': intent.keyId.isNotEmpty ? intent.keyId : keyId,
      'order_id': intent.gatewayOrderId,
      'amount': request.amount,
      'currency': 'INR',
      'name': 'Clothsy',
      'description': 'Order ${request.orderNumber}',
      'prefill': {
        'name': request.customerName,
        'contact': request.customerPhone,
      },
      'method': {_method(request.method): true},
      // Under the 15-minute stock hold, so a slow payment never outlives it.
      'timeout': 720,
      'theme': {'color': '#5C25FC'},
    });
    return completer.future;
  }

  void dispose() {
    _finish(const PaymentCancelled());
    _razorpay.clear();
  }
}
