import { denoEnv, requireEnv } from '../_shared/env.ts';
import { AppError } from '../_shared/http.ts';
import { rpc, serviceClient } from '../_shared/supabase.ts';
import { MockPaymentProvider } from '../_shared/payments/mock.ts';
import { selectPaymentProvider } from '../_shared/payments/select.ts';
import { allowMocks } from '../_shared/env.ts';
import { type ClaimedRefund, makeHandler } from './handler.ts';

const service = serviceClient(denoEnv);

Deno.serve(makeHandler({
  serviceKey: requireEnv(denoEnv, 'SUPABASE_SERVICE_ROLE_KEY'),
  pendingRefunds: (limit) => rpc<string[]>(service, 'pending_refunds', { p_limit: limit }),
  claim: (refundId) =>
    rpc<ClaimedRefund | null>(service, 'claim_refund', { p_refund_id: refundId }),
  complete: async (refundId, providerRefundId) => {
    await rpc(service, 'complete_refund', {
      p_refund_id: refundId,
      p_provider_refund_id: providerRefundId,
    });
  },
  fail: async (refundId, error) => {
    await rpc(service, 'fail_refund', { p_refund_id: refundId, p_error: error });
  },
  provider: (name) => {
    if (name === 'mock') {
      if (!allowMocks(denoEnv)) throw new AppError('PAYMENTS_NOT_CONFIGURED', 503);
      return new MockPaymentProvider(denoEnv('MOCK_WEBHOOK_SECRET'));
    }
    return selectPaymentProvider(denoEnv);
  },
}));
