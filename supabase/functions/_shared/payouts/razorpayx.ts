// RazorpayX payouts to a bank account in one call (composite payout: the
// contact and fund account travel with the payout). Idempotent on Clothsy's
// payout id. https://razorpay.com/docs/api/x/payout-composite/
//
// TODO(razorpayx): check the request against the account once it is set up
// (mode / purpose / queue_if_low_balance), and confirm `processing` payouts
// through the payout.processed / payout.reversed webhooks — until then they
// stay `processing` in Clothsy.

import type { PayoutProvider, PayoutRequest, SentPayout } from './provider.ts';

type Fetch = typeof fetch;

export class RazorpayXProvider implements PayoutProvider {
  readonly name = 'razorpayx' as const;

  constructor(
    private readonly keyId: string,
    private readonly keySecret: string,
    /// Clothsy's RazorpayX business account the money is sent from.
    private readonly accountNumber: string,
    private readonly http: Fetch = fetch,
    private readonly baseUrl = 'https://api.razorpay.com/v1',
  ) {}

  async send(input: PayoutRequest): Promise<SentPayout> {
    const res = await this.http(`${this.baseUrl}/payouts`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${btoa(`${this.keyId}:${this.keySecret}`)}`,
        'Content-Type': 'application/json',
        'X-Payout-Idempotency': input.payoutId,
      },
      body: JSON.stringify({
        account_number: this.accountNumber,
        amount: input.amount,
        currency: 'INR',
        mode: input.amount <= 50_000_000 ? 'IMPS' : 'NEFT',
        purpose: 'payout',
        queue_if_low_balance: true,
        reference_id: input.payoutId,
        narration: 'Clothsy seller payout',
        fund_account: {
          account_type: 'bank_account',
          bank_account: {
            name: input.accountHolder,
            ifsc: input.ifsc,
            account_number: input.accountNumber,
          },
          contact: { name: input.accountHolder, type: 'vendor', reference_id: input.sellerId },
        },
      }),
    });
    const data = await res.json().catch(() => ({})) as {
      id?: string;
      status?: string;
      utr?: string | null;
      error?: { description?: string };
    };
    if (!res.ok || !data.id) {
      throw new Error(
        `RazorpayX payout failed (${res.status}): ${data.error?.description ?? 'unknown'}`,
      );
    }
    if (data.status === 'rejected' || data.status === 'failed' || data.status === 'reversed') {
      throw new Error(`RazorpayX payout ${data.status}`);
    }
    return {
      providerPayoutId: data.id,
      status: data.status === 'processed' ? 'processed' : 'processing',
      utr: data.utr ?? null,
    };
  }
}
