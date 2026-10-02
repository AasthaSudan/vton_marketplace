import { assertEquals } from '@std/assert';
import { MockPaymentProvider } from '../_shared/payments/mock.ts';
import { post } from '../_shared/testing.ts';
import { type ClaimedRefund, makeHandler, type RefundDeps } from './handler.ts';

const SERVICE_KEY = 'service-key';

function fakes() {
  const claimed = new Set<string>();
  const completed: string[] = [];
  const failedIds: string[] = [];
  const deps: RefundDeps = {
    serviceKey: SERVICE_KEY,
    pendingRefunds: () => Promise.resolve(['r1', 'r2']),
    claim: (id) => {
      if (claimed.has(id)) return Promise.resolve(null);
      claimed.add(id);
      const refund: ClaimedRefund = {
        refund_id: id,
        order_id: 'o',
        provider: 'mock',
        provider_payment_id: id === 'r2' ? null : 'pay_mock_1',
        amount: 114900,
      };
      return Promise.resolve(refund);
    },
    complete: (id) => {
      completed.push(id);
      return Promise.resolve();
    },
    fail: (id) => {
      failedIds.push(id);
      return Promise.resolve();
    },
    provider: () => new MockPaymentProvider(),
  };
  return { deps, completed, failedIds };
}

Deno.test('only the service key may send refunds', async () => {
  const { deps } = fakes();
  assertEquals((await makeHandler(deps)(post({ sweep: true }, 'not-the-key'))).status, 403);
  assertEquals((await makeHandler(deps)(post({ sweep: true }))).status, 403);
});

Deno.test('a sweep sends each pending refund once and records failures', async () => {
  const { deps, completed, failedIds } = fakes();
  const handler = makeHandler(deps);
  const first = await (await handler(post({ sweep: true }, SERVICE_KEY))).json();
  assertEquals(first, { processed: ['r1'], failed: ['r2'] });
  const second = await (await handler(post({ sweep: true }, SERVICE_KEY))).json();
  assertEquals(second, { processed: [], failed: [] });
  assertEquals(completed, ['r1']);
  assertEquals(failedIds, ['r2']);
});
