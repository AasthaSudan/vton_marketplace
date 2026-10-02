import { assertEquals, assertRejects } from '@std/assert';
import { RazorpayXProvider } from './razorpayx.ts';
import { selectPayoutProvider } from './select.ts';

const request = {
  payoutId: '11111111-1111-1111-1111-111111111111',
  sellerId: 's1',
  amount: 72780,
  accountHolder: 'Noor Atelier',
  accountNumber: '50100012345678',
  ifsc: 'HDFC0000123',
};

Deno.test('a RazorpayX payout is idempotent on the Clothsy payout id', async () => {
  let seen: Request | undefined;
  const provider = new RazorpayXProvider(
    'rzp_test_x',
    'secret',
    '2323230000000000',
    (input, init) => {
      seen = new Request(input as string, init);
      return Promise.resolve(Response.json({ id: 'pout_1', status: 'processed', utr: 'UTR1' }));
    },
  );
  const sent = await provider.send(request);
  assertEquals(sent, { providerPayoutId: 'pout_1', status: 'processed', utr: 'UTR1' });
  assertEquals(seen!.headers.get('X-Payout-Idempotency'), request.payoutId);
  const body = await seen!.json();
  assertEquals(body.reference_id, request.payoutId);
  assertEquals(body.amount, 72780);
  assertEquals(body.fund_account.bank_account.account_number, '50100012345678');
});

Deno.test('a rejected RazorpayX payout is a failure', async () => {
  const provider = new RazorpayXProvider(
    'k',
    's',
    'a',
    () => Promise.resolve(Response.json({ id: 'pout_2', status: 'rejected' })),
  );
  await assertRejects(() => provider.send(request));
});

Deno.test('payouts use the mock only where mocks are allowed', () => {
  const env = (vars: Record<string, string>) => (name: string) => vars[name];
  assertEquals(selectPayoutProvider(env({ ALLOW_MOCK_PROVIDERS: 'true' })).name, 'mock');
  assertEquals(
    selectPayoutProvider(env({
      RAZORPAYX_KEY_ID: 'k',
      RAZORPAYX_KEY_SECRET: 's',
      RAZORPAYX_ACCOUNT_NUMBER: 'a',
    })).name,
    'razorpayx',
  );
  let status = 0;
  try {
    selectPayoutProvider(env({}));
  } catch (e) {
    status = (e as { status: number }).status;
  }
  assertEquals(status, 503);
});
