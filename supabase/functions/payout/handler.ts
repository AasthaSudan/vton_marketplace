// POST /payout — sends queued seller payouts to the payout rail. Called by
// pg_cron ({"sweep": true}) after the daily payout run, or for one payout
// ({"payout_id": ...}). Service key only. claim_payout hands each payout out
// once, so a seller is never paid twice.

import { z } from 'zod';
import { requireServiceKey } from '../_shared/auth.ts';
import { json, readBody, withErrors } from '../_shared/http.ts';
import type { PayoutProvider } from '../_shared/payouts/provider.ts';

const Body = z.union([
  z.object({ payout_id: z.string().uuid() }),
  z.object({ sweep: z.literal(true), limit: z.number().int().min(1).max(100).optional() }),
]);

export interface ClaimedPayout {
  payout_id: string;
  seller_id: string;
  amount: number;
  account_holder: string;
  account_number: string;
  ifsc: string;
}

export interface PayoutDeps {
  serviceKey: string;
  pendingPayouts(limit: number): Promise<string[]>;
  claim(payoutId: string): Promise<ClaimedPayout | null>;
  complete(
    payoutId: string,
    provider: string,
    providerPayoutId: string,
    utr: string | null,
  ): Promise<void>;
  fail(payoutId: string, error: string): Promise<void>;
  provider(): PayoutProvider;
}

export function makeHandler(deps: PayoutDeps) {
  return withErrors(async (req) => {
    requireServiceKey(req, deps.serviceKey);
    const body = await readBody(req, Body);
    const provider = deps.provider();
    const ids = 'payout_id' in body
      ? [body.payout_id]
      : await deps.pendingPayouts(body.limit ?? 20);

    const paid: string[] = [];
    const sent: string[] = [];
    const failed: string[] = [];
    for (const id of ids) {
      const payout = await deps.claim(id);
      if (!payout) continue;
      try {
        const result = await provider.send({
          payoutId: payout.payout_id,
          sellerId: payout.seller_id,
          amount: payout.amount,
          accountHolder: payout.account_holder,
          accountNumber: payout.account_number,
          ifsc: payout.ifsc,
        });
        if (result.status === 'processed') {
          await deps.complete(id, provider.name, result.providerPayoutId, result.utr);
          paid.push(id);
        } else {
          // Confirmed later by the provider's webhook; stays `processing`.
          sent.push(id);
        }
      } catch (e) {
        await deps.fail(id, String(e));
        failed.push(id);
      }
    }
    return json({ paid, sent, failed });
  });
}
