import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';
import '../../data/mock_payment_gateway.dart';

/// The active payment gateway. The Razorpay implementation replaces the mock
/// once `RAZORPAY_KEY_ID` is configured for the build.
final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  return MockPaymentGateway();
});
