import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/features/payments/domain/payment_gateway.dart';
import '../../../../core/config/app_config_provider.dart';
import '../../data/mock_payment_gateway.dart';
import '../../data/razorpay_payment_gateway.dart';

/// The active payment gateway: Razorpay's checkout on Android/iOS when a key
/// is configured, otherwise the mock (which only the mock or a local
/// backend's mock payment provider accepts).
final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.usesRazorpay) {
    final gateway = RazorpayPaymentGateway(config.razorpayKeyId);
    ref.onDispose(gateway.dispose);
    return gateway;
  }
  return MockPaymentGateway();
});
