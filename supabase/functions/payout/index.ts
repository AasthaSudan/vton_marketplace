import { denoEnv, requireEnv } from '../_shared/env.ts';
import { rpc, serviceClient } from '../_shared/supabase.ts';
import { selectPayoutProvider } from '../_shared/payouts/select.ts';
import { type ClaimedPayout, makeHandler } from './handler.ts';

const service = serviceClient(denoEnv);

Deno.serve(makeHandler({
  serviceKey: requireEnv(denoEnv, 'SUPABASE_SERVICE_ROLE_KEY'),
  pendingPayouts: (limit) => rpc<string[]>(service, 'pending_payouts', { p_limit: limit }),
  claim: (payoutId) =>
    rpc<ClaimedPayout | null>(service, 'claim_payout', { p_payout_id: payoutId }),
  complete: async (payoutId, provider, providerPayoutId, utr) => {
    await rpc(service, 'complete_payout', {
      p_payout_id: payoutId,
      p_provider: provider,
      p_provider_payout_id: providerPayoutId,
      p_utr: utr,
    });
  },
  fail: async (payoutId, error) => {
    await rpc(service, 'fail_payout', { p_payout_id: payoutId, p_error: error });
  },
  provider: () => selectPayoutProvider(denoEnv),
}));
