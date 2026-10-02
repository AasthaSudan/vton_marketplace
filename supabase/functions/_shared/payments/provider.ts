// What Clothsy needs from a payment gateway. Amounts are integer paise.

export interface CreatedOrder {
  providerOrderId: string;
}

export interface FetchedPayment {
  status: string;
  amount: number;
  orderId: string | null;
}

export interface CreatedRefund {
  providerRefundId: string;
  status: string;
}

export interface PaymentProvider {
  /// `razorpay` or `mock`, as stored in payments.provider.
  readonly name: 'razorpay' | 'mock';
  /// Public key id the app opens checkout with.
  readonly keyId: string;
  createOrder(input: {
    amount: number;
    receipt: string;
    notes?: Record<string, string>;
  }): Promise<CreatedOrder>;
  /// Checks the signature the checkout sheet returned to the app.
  verifyPaymentSignature(input: {
    providerOrderId: string;
    paymentId: string;
    signature: string;
  }): Promise<boolean>;
  /// Asks the gateway what really happened (never trust the client).
  fetchPayment(paymentId: string): Promise<FetchedPayment>;
  /// Checks a webhook against its raw body.
  verifyWebhookSignature(rawBody: string, signature: string | null): Promise<boolean>;
  refund(input: {
    paymentId: string;
    amount: number;
    receipt: string;
  }): Promise<CreatedRefund>;
}
