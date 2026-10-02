import { denoEnv } from '../_shared/env.ts';
import { rpc, serviceClient, userClient } from '../_shared/supabase.ts';
import { selectPaymentProvider } from '../_shared/payments/select.ts';
import { makeHandler } from './handler.ts';

const service = serviceClient(denoEnv);

Deno.serve(makeHandler({
  findOwnOrder: async (token, orderId) => {
    const { data } = await userClient(denoEnv, token).from('orders').select('id')
      .eq('id', orderId).maybeSingle();
    return data;
  },
  findPayment: async (orderId, providerOrderId) => {
    const { data } = await service.from('payments').select('provider, amount')
      .eq('order_id', orderId).eq('provider_order_id', providerOrderId).maybeSingle();
    return data;
  },
  confirmPayment: (input) =>
    rpc(service, 'confirm_payment', {
      p_order_id: input.orderId,
      p_provider_order_id: input.providerOrderId,
      p_provider_payment_id: input.providerPaymentId,
      p_amount: input.amount,
      p_source: 'client_verify',
    }),
  provider: () => selectPaymentProvider(denoEnv),
}));
