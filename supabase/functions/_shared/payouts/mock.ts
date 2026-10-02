// Local stand-in for a payout rail: no network, deterministic references.

import type { PayoutProvider, PayoutRequest } from './provider.ts';

export class MockPayoutProvider implements PayoutProvider {
  readonly name = 'mock' as const;

  send(input: PayoutRequest) {
    const ref = input.payoutId.replaceAll('-', '').slice(0, 12).toUpperCase();
    return Promise.resolve({
      providerPayoutId: `pout_mock_${ref}`,
      status: 'processed' as const,
      utr: `MOCKUTR${ref}`,
    });
  }
}
