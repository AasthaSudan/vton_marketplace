import { assertEquals } from '@std/assert';
import { RazorpayProvider } from '../_shared/payments/razorpay.ts';
import { MockPaymentProvider } from '../_shared/payments/mock.ts';
import { post, userToken } from '../_shared/testing.ts';
import { makeHandler, type VerifyPaymentDeps } from './handler.ts';

const body = {
  order_id: '55555555-5555-5555-5555-555555555555',
  provider_order_id: 'order_TEST000000001',
  provider_payment_id: 'pay_TEST000000001',
  signature: '28bec8bfe704360e9f37bc209048e882b60231119f2515147fa36777a5084884',
};

function fakes(
  provider = 'razorpay',
  fetched = { status: 'captured', amount: 449900, orderId: 'order_TEST000000001' },
) {
  const confirmed: string[] = [];
  const deps: VerifyPaymentDeps = {
    findOwnOrder: () => Promise.resolve({ id: body.order_id }),
    findPayment: () => Promise.resolve({ provider, amount: 449900 }),
    confirmPayment: (input) => {
      confirmed.push(input.providerPaymentId);
      return Promise.resolve({ payment_status: 'paid' });
    },
    provider: () => {
      if (provider === 'mock') return new MockPaymentProvider();
      const p = new RazorpayProvider('rzp_test_key', 'clothsy_test_key_secret', 'w');
      p.fetchPayment = () => Promise.resolve(fetched);
      return p;
    },
  };
  return { deps, confirmed };
}

Deno.test('a signed, captured payment confirms the order', async () => {
  const { deps, confirmed } = fakes();
  const res = await makeHandler(deps)(post(body, userToken()));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).payment_status, 'paid');
  assertEquals(confirmed, ['pay_TEST000000001']);
});

Deno.test('a bad signature never confirms', async () => {
  const { deps, confirmed } = fakes();
  const res = await makeHandler(deps)(post({ ...body, signature: 'forged' }, userToken()));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error.code, 'SIGNATURE_INVALID');
  assertEquals(confirmed, []);
});

Deno.test('not captured yet, or the wrong amount: wait for the webhook', async () => {
  for (
    const fetched of [
      { status: 'authorized', amount: 449900, orderId: 'order_TEST000000001' },
      { status: 'captured', amount: 1, orderId: 'order_TEST000000001' },
      { status: 'captured', amount: 449900, orderId: 'order_OTHER' },
    ]
  ) {
    const { deps, confirmed } = fakes('razorpay', fetched);
    const res = await makeHandler(deps)(post(body, userToken()));
    assertEquals(res.status, 202);
    assertEquals(confirmed, []);
  }
});

Deno.test("another shopper's order is not found", async () => {
  const { deps } = fakes();
  deps.findOwnOrder = () => Promise.resolve(null);
  assertEquals((await makeHandler(deps)(post(body, userToken()))).status, 404);
});

Deno.test('local mock payments confirm with a pay_mock id', async () => {
  const { deps, confirmed } = fakes('mock');
  const res = await makeHandler(deps)(
    post({ ...body, provider_payment_id: 'pay_mock_1', signature: '' }, userToken()),
  );
  assertEquals(res.status, 200);
  assertEquals(confirmed, ['pay_mock_1']);
});
