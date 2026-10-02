// Razorpay over its REST API (https://razorpay.com/docs/api/).
//   payment signature = HMAC_SHA256(key_secret, "<order_id>|<payment_id>")
//   webhook signature = HMAC_SHA256(webhook_secret, <raw body>)

import { hmacSha256Hex, timingSafeEqual } from '../hmac.ts';
import type { PaymentProvider } from './provider.ts';

type Fetch = typeof fetch;

export class RazorpayProvider implements PaymentProvider {
  readonly name = 'razorpay' as const;

  constructor(
    readonly keyId: string,
    private readonly keySecret: string,
    private readonly webhookSecret: string,
    private readonly http: Fetch = fetch,
    private readonly baseUrl = 'https://api.razorpay.com/v1',
  ) {}

  private async call<T>(method: string, path: string, body?: unknown): Promise<T> {
    const res = await this.http(`${this.baseUrl}${path}`, {
      method,
      headers: {
        Authorization: `Basic ${btoa(`${this.keyId}:${this.keySecret}`)}`,
        'Content-Type': 'application/json',
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      const description = (data as { error?: { description?: string } }).error?.description;
      throw new Error(`Razorpay ${path} failed (${res.status}): ${description ?? 'unknown'}`);
    }
    return data as T;
  }

  async createOrder(input: { amount: number; receipt: string; notes?: Record<string, string> }) {
    const order = await this.call<{ id: string }>('POST', '/orders', {
      amount: input.amount,
      currency: 'INR',
      receipt: input.receipt,
      notes: input.notes,
    });
    return { providerOrderId: order.id };
  }

  async verifyPaymentSignature(input: {
    providerOrderId: string;
    paymentId: string;
    signature: string;
  }) {
    const expected = await hmacSha256Hex(
      this.keySecret,
      `${input.providerOrderId}|${input.paymentId}`,
    );
    return timingSafeEqual(expected, input.signature);
  }

  async fetchPayment(paymentId: string) {
    const p = await this.call<{ status: string; amount: number; order_id: string | null }>(
      'GET',
      `/payments/${encodeURIComponent(paymentId)}`,
    );
    return { status: p.status, amount: p.amount, orderId: p.order_id };
  }

  async verifyWebhookSignature(rawBody: string, signature: string | null) {
    if (!signature || !this.webhookSecret) return false;
    const expected = await hmacSha256Hex(this.webhookSecret, rawBody);
    return timingSafeEqual(expected, signature);
  }

  async refund(input: { paymentId: string; amount: number; receipt: string }) {
    const r = await this.call<{ id: string; status: string }>(
      'POST',
      `/payments/${encodeURIComponent(input.paymentId)}/refund`,
      { amount: input.amount, receipt: input.receipt, speed: 'normal' },
    );
    return { providerRefundId: r.id, status: r.status };
  }
}
