import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';

/// Stand-in gateway for the mock flavor and tests: succeeds after a short
/// delay unless a [responder] says otherwise. Replaced by the Razorpay-backed
/// gateway once real keys are configured.
class MockPaymentGateway implements PaymentGateway {
  final Duration delay;
  final PaymentResult Function(PaymentRequest request)? responder;

  /// Every request this gateway has been asked to collect (for tests).
  final List<PaymentRequest> requests = [];

  MockPaymentGateway({
    this.delay = const Duration(milliseconds: 900),
    this.responder,
  });

  @override
  Future<PaymentResult> pay(PaymentRequest request) async {
    requests.add(request);
    await Future.delayed(delay);
    return responder?.call(request) ??
        PaymentSuccess(paymentRef: 'pay_mock_${request.orderId}');
  }
}
