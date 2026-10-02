import { assertEquals } from '@std/assert';
import { MockPayoutProvider } from '../_shared/payouts/mock.ts';
import type { PayoutProvider } from '../_shared/payouts/provider.ts';
import { post } from '../_shared/testing.ts';
import { type ClaimedPayout, makeHandler, type PayoutDeps } from './handler.ts';

const SERVICE_KEY = 'service-key';

function fakes(provider: PayoutProvider = new MockPayoutProvider()) {
  const claimed = new Set<string>();
  const completed: Array<[string, string, string | null]> = [];
  const failedIds: string[] = [];
  const deps: PayoutDeps = {
    serviceKey: SERVICE_KEY,
    pendingPayouts: () =>
      Promise.resolve([
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
      ]),
    claim: (id) => {
      if (claimed.has(id)) return Promise.resolve(null);
      claimed.add(id);
      const payout: ClaimedPayout = {
        payout_id: id,
        seller_id: 's1',
        amount: 72780,
        account_holder: 'Noor Atelier',
        account_number: id.startsWith('2') ? 'bad' : '50100012345678',
        ifsc: 'HDFC0000123',
      };
      return Promise.resolve(payout);
    },
    complete: (id, _provider, providerPayoutId, utr) => {
      completed.push([id, providerPayoutId, utr]);
      return Promise.resolve();
    },
    fail: (id) => {
      failedIds.push(id);
      return Promise.resolve();
    },
    provider: () => provider,
  };
  return { deps, completed, failedIds };
}

/// Pays everyone except account number "bad".
class PickyProvider extends MockPayoutProvider {
  override send(input: Parameters<MockPayoutProvider['send']>[0]) {
    if (input.accountNumber === 'bad') return Promise.reject(new Error('IFSC/account mismatch'));
    return super.send(input);
  }
}

Deno.test('only the service key may send payouts', async () => {
  const { deps } = fakes();
  assertEquals((await makeHandler(deps)(post({ sweep: true }, 'not-the-key'))).status, 403);
  assertEquals((await makeHandler(deps)(post({ sweep: true }))).status, 403);
});

Deno.test('a sweep pays each queued payout once and records failures', async () => {
  const { deps, completed, failedIds } = fakes(new PickyProvider());
  const handler = makeHandler(deps);
  const first = await (await handler(post({ sweep: true }, SERVICE_KEY))).json();
  assertEquals(first, {
    paid: ['11111111-1111-1111-1111-111111111111'],
    sent: [],
    failed: ['22222222-2222-2222-2222-222222222222'],
  });
  const second = await (await handler(post({ sweep: true }, SERVICE_KEY))).json();
  assertEquals(second, { paid: [], sent: [], failed: [] });
  assertEquals(completed, [[
    '11111111-1111-1111-1111-111111111111',
    'pout_mock_111111111111',
    'MOCKUTR111111111111',
  ]]);
  assertEquals(failedIds, ['22222222-2222-2222-2222-222222222222']);
});

Deno.test('a payout the provider is still processing is not marked paid', async () => {
  const slow: PayoutProvider = {
    name: 'razorpayx',
    send: () => Promise.resolve({ providerPayoutId: 'pout_1', status: 'processing', utr: null }),
  };
  const { deps, completed } = fakes(slow);
  const res = await (await makeHandler(deps)(
    post({ payout_id: '11111111-1111-1111-1111-111111111111' }, SERVICE_KEY),
  )).json();
  assertEquals(res.sent, ['11111111-1111-1111-1111-111111111111']);
  assertEquals(completed, []);
});
