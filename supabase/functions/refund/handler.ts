// POST /refund — sends refunds from the outbox to the payment provider.
// Called by pg_cron every few minutes ({"sweep": true}) or for one refund
// ({"refund_id": ...}). Service key only. claim_refund hands each refund out
// once, so a refund is never sent twice.

import { z } from 'zod';
import { requireServiceKey } from '../_shared/auth.ts';
import { json, readBody, withErrors } from '../_shared/http.ts';
import type { PaymentProvider } from '../_shared/payments/provider.ts';

const Body = z.union([
  z.object({ refund_id: z.string().uuid() }),
  z.object({ sweep: z.literal(true), limit: z.number().int().min(1).max(100).optional() }),
]);

export interface ClaimedRefund {
  refund_id: string;
  order_id: string;
  provider: 'razorpay' | 'mock' | null;
  provider_payment_id: string | null;
  amount: number;
}

export interface RefundDeps {
  serviceKey: string;
  pendingRefunds(limit: number): Promise<string[]>;
  claim(refundId: string): Promise<ClaimedRefund | null>;
  complete(refundId: string, providerRefundId: string): Promise<void>;
  fail(refundId: string, error: string): Promise<void>;
  /// The provider that took the payment.
  provider(name: 'razorpay' | 'mock'): PaymentProvider;
}

export function makeHandler(deps: RefundDeps) {
  return withErrors(async (req) => {
    requireServiceKey(req, deps.serviceKey);
    const body = await readBody(req, Body);
    const ids = 'refund_id' in body
      ? [body.refund_id]
      : await deps.pendingRefunds(body.limit ?? 20);

    const processed: string[] = [];
    const failed: string[] = [];
    for (const id of ids) {
      const refund = await deps.claim(id);
      if (!refund) continue;
      try {
        if (!refund.provider || !refund.provider_payment_id) {
          throw new Error('refund has no captured payment');
        }
        const result = await deps.provider(refund.provider).refund({
          paymentId: refund.provider_payment_id,
          amount: refund.amount,
          receipt: refund.refund_id,
        });
        await deps.complete(id, result.providerRefundId);
        processed.push(id);
      } catch (e) {
        await deps.fail(id, String(e));
        failed.push(id);
      }
    }
    return json({ processed, failed });
  });
}
