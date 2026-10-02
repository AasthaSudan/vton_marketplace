// POST /verify-payment — the app reports a successful checkout. Clothsy
// checks the gateway's signature and asks the gateway what really happened
// before the order counts as paid (Blueprint fig. 19). The webhook confirms
// independently; whichever arrives first wins, the other is a no-op.

import { z } from 'zod';
import { requireUser } from '../_shared/auth.ts';
import { AppError, json, readBody, withErrors } from '../_shared/http.ts';
import type { PaymentProvider } from '../_shared/payments/provider.ts';

const Body = z.object({
  order_id: z.string().uuid(),
  provider_order_id: z.string().min(1),
  provider_payment_id: z.string().min(1),
  signature: z.string().default(''),
});

export interface VerifyPaymentDeps {
  /// The order, read as the shopper (null when it is not theirs).
  findOwnOrder(token: string, orderId: string): Promise<{ id: string } | null>;
  findPayment(
    orderId: string,
    providerOrderId: string,
  ): Promise<{ provider: string; amount: number } | null>;
  confirmPayment(input: {
    orderId: string;
    providerOrderId: string;
    providerPaymentId: string;
    amount: number;
  }): Promise<{ payment_status: string; error?: string }>;
  provider(): PaymentProvider;
}

export function makeHandler(deps: VerifyPaymentDeps) {
  return withErrors(async (req) => {
    const caller = requireUser(req);
    const body = await readBody(req, Body);

    const order = await deps.findOwnOrder(caller.token, body.order_id);
    if (!order) throw new AppError('ORDER_NOT_FOUND', 404);
    const payment = await deps.findPayment(body.order_id, body.provider_order_id);
    if (!payment) throw new AppError('PAYMENT_NOT_FOUND', 404);

    const provider = deps.provider();
    if (provider.name !== payment.provider) {
      throw new AppError('PAYMENT_PROVIDER_MISMATCH', 409);
    }
    const signed = await provider.verifyPaymentSignature({
      providerOrderId: body.provider_order_id,
      paymentId: body.provider_payment_id,
      signature: body.signature,
    });
    if (!signed) {
      // Not proof of payment; the webhook may still confirm a real one.
      console.warn('payment signature mismatch', body.order_id);
      throw new AppError('SIGNATURE_INVALID', 400, 'Payment could not be verified');
    }

    if (provider.name !== 'mock') {
      const fetched = await provider.fetchPayment(body.provider_payment_id);
      if (
        fetched.status !== 'captured' ||
        fetched.amount !== payment.amount ||
        fetched.orderId !== body.provider_order_id
      ) {
        // Authorised but not captured yet (or not this order): wait for the
        // webhook rather than trusting the app.
        return json({ order_id: body.order_id, payment_status: 'pending', confirming: true }, 202);
      }
    }

    const result = await deps.confirmPayment({
      orderId: body.order_id,
      providerOrderId: body.provider_order_id,
      providerPaymentId: body.provider_payment_id,
      amount: payment.amount,
    });
    if (result.error) throw new AppError(result.error, 409);
    return json({ order_id: body.order_id, payment_status: result.payment_status });
  });
}
