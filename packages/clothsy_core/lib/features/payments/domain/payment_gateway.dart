/// How the customer chose to pay.
enum PaymentMethod {
  upi,
  card,
  netBanking,
  cashOnDelivery;

  /// Paid online now, so the order waits for payment confirmation.
  bool get isPrepaid => this != PaymentMethod.cashOnDelivery;

  /// Where a refund lands, in customer words ("reaches your UPI").
  String get refundDestination {
    switch (this) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.netBanking:
        return 'bank account';
      case PaymentMethod.cashOnDelivery:
        return 'payment method';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.netBanking:
        return 'Net banking';
      case PaymentMethod.cashOnDelivery:
        return 'Cash on delivery';
    }
  }
}

/// What the order service set up with the gateway for a prepaid order
/// (e.g. a Razorpay order the checkout sheet must be opened with).
class PaymentIntent {
  /// `razorpay` or `mock`.
  final String provider;

  /// Public key id the checkout sheet is opened with.
  final String keyId;

  /// The gateway's order id (Razorpay `order_...`).
  final String gatewayOrderId;

  const PaymentIntent({
    required this.provider,
    required this.keyId,
    required this.gatewayOrderId,
  });
}

/// Everything a gateway needs to collect one payment.
///
/// [amount] is integer paise and must come from the server-created order — the
/// app never decides what to charge.
class PaymentRequest {
  final String orderId;
  final String orderNumber;
  final int amount;
  final PaymentMethod method;
  final String customerName;
  final String customerPhone;

  /// Preferred UPI app, when [method] is UPI (e.g. `Google Pay`).
  final String? upiApp;

  /// The gateway order to pay, when the order service created one.
  final PaymentIntent? intent;

  const PaymentRequest({
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.method,
    required this.customerName,
    required this.customerPhone,
    this.upiApp,
    this.intent,
  });
}

/// Outcome of asking a gateway to collect a payment.
sealed class PaymentResult {
  const PaymentResult();
}

/// The gateway reports success. This is only a *claim* — Clothsy confirms it
/// server-side (signature check and webhook) before the order counts as paid.
class PaymentSuccess extends PaymentResult {
  /// Gateway payment id (e.g. Razorpay `pay_...`).
  final String paymentRef;

  /// Gateway signature the server verifies, when the gateway provides one.
  final String? signature;

  /// The gateway order the payment belongs to (Razorpay `order_...`).
  final String? gatewayOrderId;

  const PaymentSuccess({
    required this.paymentRef,
    this.signature,
    this.gatewayOrderId,
  });
}

/// The payment did not go through (declined, timed out, bank error).
class PaymentFailure extends PaymentResult {
  final String message;
  const PaymentFailure(this.message);
}

/// The customer closed the payment sheet without paying.
class PaymentCancelled extends PaymentResult {
  const PaymentCancelled();
}

/// Collects a payment for an order. The Razorpay-backed implementation plugs
/// in here; the app ships a mock gateway until real keys are configured.
abstract class PaymentGateway {
  Future<PaymentResult> pay(PaymentRequest request);
}
