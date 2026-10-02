// POST /create-order — places the order on the server (prices, stock and
// coupon re-checked by place_order) and, for online payment, creates the
// gateway order the app's checkout sheet pays. Idempotent per checkout.

import { z } from 'zod';
import { requireUser } from '../_shared/auth.ts';
import { AppError, json, readBody, withErrors } from '../_shared/http.ts';
import type { PaymentProvider } from '../_shared/payments/provider.ts';

const Body = z.object({
  items: z.array(z.object({ variant_id: z.string(), quantity: z.number().int() })).min(1).max(50),
  address_id: z.string().uuid(),
  payment_method: z.enum(['upi', 'card', 'net_banking', 'cod']),
  payment_label: z.string().max(80).default(''),
  coupon_code: z.string().max(40).nullish(),
  idempotency_key: z.string().uuid(),
  expected_total: z.number().int().nullish(),
});
export type CreateOrderBody = z.infer<typeof Body>;

export interface PlacedOrder {
  order_id: string;
  order_number: string;
  grand_total: number;
  payment_status: 'pending' | 'cod' | 'paid' | 'failed' | 'partially_refunded' | 'refunded';
  replayed: boolean;
}

export interface CreateOrderDeps {
  /// place_order, run as the shopper.
  placeOrder(token: string, body: CreateOrderBody): Promise<PlacedOrder>;
  /// The live gateway order for [orderId], if one was already created.
  findPaymentIntent(
    orderId: string,
  ): Promise<{ provider: string; provider_order_id: string } | null>;
  recordPaymentIntent(
    orderId: string,
    provider: string,
    providerOrderId: string,
    amount: number,
  ): Promise<{ provider_order_id: string }>;
  failPayment(orderId: string, reason: string): Promise<void>;
  /// Throws AppError(503) when no payment provider is configured.
  provider(): PaymentProvider;
}

export function makeHandler(deps: CreateOrderDeps) {
  return withErrors(async (req) => {
    const caller = requireUser(req);
    const body = await readBody(req, Body);
    const order = await deps.placeOrder(caller.token, body);

    const base = {
      order_id: order.order_id,
      order_number: order.order_number,
      amount: order.grand_total,
      currency: 'INR',
      payment_status: order.payment_status,
    };
    if (order.payment_status !== 'pending') return json({ ...base, payment: null });

    let provider: PaymentProvider;
    try {
      provider = deps.provider();
    } catch (e) {
      // No way to pay online: release the stock straight away.
      await deps.failPayment(order.order_id, 'payments_unavailable');
      throw e;
    }

    // A retried checkout reuses the gateway order it already has.
    const existing = await deps.findPaymentIntent(order.order_id);
    if (existing) {
      return json({
        ...base,
        payment: {
          provider: existing.provider,
          key_id: provider.keyId,
          provider_order_id: existing.provider_order_id,
        },
      });
    }

    let providerOrderId: string;
    try {
      const created = await provider.createOrder({
        amount: order.grand_total,
        receipt: order.order_number,
        notes: { clothsy_order_id: order.order_id },
      });
      providerOrderId = created.providerOrderId;
    } catch (e) {
      console.error('gateway order failed', e);
      await deps.failPayment(order.order_id, 'gateway_error');
      throw new AppError(
        'PAYMENT_GATEWAY_ERROR',
        502,
        "We couldn't reach the payment service. Nothing was charged.",
      );
    }

    // If two retries raced, the database keeps one intent and both get it.
    const intent = await deps.recordPaymentIntent(
      order.order_id,
      provider.name,
      providerOrderId,
      order.grand_total,
    );
    return json({
      ...base,
      payment: {
        provider: provider.name,
        key_id: provider.keyId,
        provider_order_id: intent.provider_order_id,
      },
    });
  });
}
