// Local stand-in for Razorpay: no network, deterministic ids. The app's
// MockPaymentGateway pays with `pay_mock_*` ids, which only this provider
// accepts. Webhooks are still HMAC-checked so that code path is exercised.

import { hmacSha256Hex, timingSafeEqual } from '../hmac.ts';
import type { PaymentProvider } from './provider.ts';

export class MockPaymentProvider implements PaymentProvider {
  readonly name = 'mock' as const;
  readonly keyId = 'rzp_test_mock';

  constructor(private readonly webhookSecret = 'clothsy-local-webhook-secret') {}

  createOrder(_input: { amount: number; receipt: string }) {
    const id = `order_mock_${crypto.randomUUID().replaceAll('-', '').slice(0, 14)}`;
    return Promise.resolve({ providerOrderId: id });
  }

  verifyPaymentSignature(input: { paymentId: string }) {
    return Promise.resolve(input.paymentId.startsWith('pay_mock_'));
  }

  /// The mock keeps no state between requests, so it cannot report the
  /// amount; callers skip the amount re-check for the mock (amount -1).
  fetchPayment(_paymentId: string) {
    return Promise.resolve({ status: 'captured', amount: -1, orderId: null });
  }

  async verifyWebhookSignature(rawBody: string, signature: string | null) {
    if (!signature) return false;
    return timingSafeEqual(await hmacSha256Hex(this.webhookSecret, rawBody), signature);
  }

  refund(input: { paymentId: string; receipt: string }) {
    return Promise.resolve({ providerRefundId: `rfnd_mock_${input.receipt}`, status: 'processed' });
  }
}
