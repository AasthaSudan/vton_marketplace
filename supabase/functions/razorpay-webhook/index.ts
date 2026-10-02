import { denoEnv } from '../_shared/env.ts';
import { rpc, serviceClient } from '../_shared/supabase.ts';
import { selectPaymentProvider } from '../_shared/payments/select.ts';
import { makeHandler } from './handler.ts';

const service = serviceClient(denoEnv);
const providerName = () => selectPaymentProvider(denoEnv).name;

Deno.serve(makeHandler({
  provider: () => selectPaymentProvider(denoEnv),
  storeEvent: async (eventId, type, payload) => {
    await service.from('webhook_events').upsert(
      { provider: providerName(), event_id: eventId, event_type: type, payload },
      { onConflict: 'provider,event_id', ignoreDuplicates: true },
    );
    const { data } = await service.from('webhook_events').select('processed_at')
      .eq('provider', providerName()).eq('event_id', eventId).single();
    return !data?.processed_at;
  },
  markProcessed: async (eventId) => {
    await service.from('webhook_events').update({ processed_at: new Date().toISOString() })
      .eq('provider', providerName()).eq('event_id', eventId);
  },
  markFailed: async (eventId, error) => {
    const { data } = await service.from('webhook_events').select('attempts')
      .eq('provider', providerName()).eq('event_id', eventId).single();
    await service.from('webhook_events')
      .update({ attempts: (data?.attempts ?? 0) + 1, last_error: error.slice(0, 500) })
      .eq('provider', providerName()).eq('event_id', eventId);
  },
  findPayment: async (providerOrderId) => {
    const { data } = await service.from('payments').select('order_id, amount')
      .eq('provider_order_id', providerOrderId).maybeSingle();
    return data;
  },
  confirmPayment: (input) =>
    rpc(service, 'confirm_payment', {
      p_order_id: input.orderId,
      p_provider_order_id: input.providerOrderId,
      p_provider_payment_id: input.providerPaymentId,
      p_amount: input.amount,
      p_source: 'webhook',
    }),
}));
