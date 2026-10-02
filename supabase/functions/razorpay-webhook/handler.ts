// POST /razorpay-webhook — Razorpay tells Clothsy what happened. The HMAC of
// the raw body is the authentication; each event is stored once (dedupe on
// its id) and processed idempotently, so retries and duplicates are safe.

import { json } from '../_shared/http.ts';
import { hmacSha256Hex } from '../_shared/hmac.ts';
import type { PaymentProvider } from '../_shared/payments/provider.ts';

export interface WebhookDeps {
  provider(): PaymentProvider;
  /// Stores the event; false when it was already processed.
  storeEvent(eventId: string, type: string, payload: unknown): Promise<boolean>;
  markProcessed(eventId: string): Promise<void>;
  markFailed(eventId: string, error: string): Promise<void>;
  /// Our payment for a gateway order (null for orders that are not ours).
  findPayment(providerOrderId: string): Promise<{ order_id: string; amount: number } | null>;
  confirmPayment(input: {
    orderId: string;
    providerOrderId: string;
    providerPaymentId: string;
    amount: number;
  }): Promise<unknown>;
}

interface RazorpayEvent {
  event?: string;
  payload?: {
    payment?: { entity?: { id?: string; order_id?: string; amount?: number; status?: string } };
  };
}

export function makeHandler(deps: WebhookDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== 'POST') return json({ error: 'POST only' }, 405);
    const raw = await req.text();
    const provider = deps.provider();
    const valid = await provider.verifyWebhookSignature(
      raw,
      req.headers.get('x-razorpay-signature'),
    );
    if (!valid) return json({ error: 'invalid signature' }, 401);

    let event: RazorpayEvent;
    try {
      event = JSON.parse(raw);
    } catch {
      return json({ error: 'invalid body' }, 400);
    }
    const eventId = req.headers.get('x-razorpay-event-id') ?? await hmacSha256Hex('event', raw);
    const type = event.event ?? 'unknown';

    if (!(await deps.storeEvent(eventId, type, event))) {
      return json({ ok: true, duplicate: true });
    }

    try {
      if (type === 'payment.captured' || type === 'order.paid') {
        const entity = event.payload?.payment?.entity;
        if (entity?.id && entity.order_id && typeof entity.amount === 'number') {
          const payment = await deps.findPayment(entity.order_id);
          if (payment) {
            await deps.confirmPayment({
              orderId: payment.order_id,
              providerOrderId: entity.order_id,
              providerPaymentId: entity.id,
              amount: entity.amount,
            });
          }
        }
      }
      // payment.failed needs no change: the order stays payable until its
      // hold expires. Refund events are settled by the refund function.
      await deps.markProcessed(eventId);
      return json({ ok: true });
    } catch (e) {
      // 500 makes Razorpay retry; the stored event is processed next time.
      await deps.markFailed(eventId, String(e));
      return json({ error: 'processing failed' }, 500);
    }
  };
}
