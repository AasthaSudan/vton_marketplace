import { denoEnv } from '../_shared/env.ts';
import { rpc, serviceClient, userClient } from '../_shared/supabase.ts';
import { selectPaymentProvider } from '../_shared/payments/select.ts';
import { makeHandler, type PlacedOrder } from './handler.ts';

const service = serviceClient(denoEnv);

Deno.serve(makeHandler({
  placeOrder: (token, body) =>
    rpc<PlacedOrder>(userClient(denoEnv, token), 'place_order', {
      p_items: body.items,
      p_address_id: body.address_id,
      p_payment_method: body.payment_method,
      p_payment_label: body.payment_label,
      p_coupon_code: body.coupon_code ?? null,
      p_idempotency_key: body.idempotency_key,
      p_expected_total: body.expected_total ?? null,
    }),
  findPaymentIntent: async (orderId) => {
    const { data } = await service.from('payments')
      .select('provider, provider_order_id')
      .eq('order_id', orderId)
      .in('state', ['created', 'captured'])
      .maybeSingle();
    return data;
  },
  recordPaymentIntent: (orderId, provider, providerOrderId, amount) =>
    rpc(service, 'record_payment_intent', {
      p_order_id: orderId,
      p_provider: provider,
      p_provider_order_id: providerOrderId,
      p_amount: amount,
    }),
  failPayment: async (orderId, reason) => {
    await rpc(service, 'fail_payment', { p_order_id: orderId, p_reason: reason });
  },
  provider: () => selectPaymentProvider(denoEnv),
}));
