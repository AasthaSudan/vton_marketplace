import { assertEquals } from '@std/assert';
import { MockPaymentProvider } from '../_shared/payments/mock.ts';
import { AppError } from '../_shared/http.ts';
import { post, userToken } from '../_shared/testing.ts';
import { type CreateOrderDeps, makeHandler, type PlacedOrder } from './handler.ts';

const body = {
  items: [{ variant_id: '22222222-2222-2222-2222-222222222222', quantity: 1 }],
  address_id: '33333333-3333-3333-3333-333333333333',
  payment_method: 'upi',
  payment_label: 'UPI (Google Pay)',
  idempotency_key: '44444444-4444-4444-4444-444444444444',
  expected_total: 114900,
};

function fakes(placed: Partial<PlacedOrder> = {}) {
  const intents = new Map<string, string>();
  const failed: string[] = [];
  let providerOrders = 0;
  const provider = new MockPaymentProvider();
  const original = provider.createOrder.bind(provider);
  provider.createOrder = (input) => {
    providerOrders++;
    return original(input);
  };
  const deps: CreateOrderDeps = {
    placeOrder: () =>
      Promise.resolve({
        order_id: 'order-1',
        order_number: 'CLY-00000001',
        grand_total: 114900,
        payment_status: 'pending',
        replayed: false,
        ...placed,
      }),
    findPaymentIntent: (id) =>
      Promise.resolve(
        intents.has(id) ? { provider: 'mock', provider_order_id: intents.get(id)! } : null,
      ),
    recordPaymentIntent: (id, _p, providerOrderId) => {
      if (!intents.has(id)) intents.set(id, providerOrderId);
      return Promise.resolve({ provider_order_id: intents.get(id)! });
    },
    failPayment: (id) => {
      failed.push(id);
      return Promise.resolve();
    },
    provider: () => provider,
  };
  return { deps, failed, providerOrders: () => providerOrders };
}

Deno.test('cash on delivery needs no payment', async () => {
  const { deps, providerOrders } = fakes({ payment_status: 'cod' });
  const res = await makeHandler(deps)(post({ ...body, payment_method: 'cod' }, userToken()));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).payment, null);
  assertEquals(providerOrders(), 0);
});

Deno.test('prepaid orders get exactly one gateway order, even on retry', async () => {
  const { deps, providerOrders } = fakes();
  const handler = makeHandler(deps);
  const first = await (await handler(post(body, userToken()))).json();
  const retry = await (await handler(post(body, userToken()))).json();
  assertEquals(first.payment.provider, 'mock');
  assertEquals(retry.payment.provider_order_id, first.payment.provider_order_id);
  assertEquals(providerOrders(), 1);
  assertEquals(first.amount, 114900);
});

Deno.test('a gateway failure releases the order and charges nothing', async () => {
  const { deps, failed } = fakes();
  deps.provider = () => {
    const p = new MockPaymentProvider();
    p.createOrder = () => Promise.reject(new Error('down'));
    return p;
  };
  const res = await makeHandler(deps)(post(body, userToken()));
  assertEquals(res.status, 502);
  assertEquals((await res.json()).error.code, 'PAYMENT_GATEWAY_ERROR');
  assertEquals(failed, ['order-1']);
});

Deno.test('no payment provider configured → order released, 503', async () => {
  const { deps, failed } = fakes();
  deps.provider = () => {
    throw new AppError('PAYMENTS_NOT_CONFIGURED', 503);
  };
  const res = await makeHandler(deps)(post(body, userToken()));
  assertEquals(res.status, 503);
  assertEquals(failed, ['order-1']);
});

Deno.test('order errors from the database reach the app with their code', async () => {
  const { deps } = fakes();
  deps.placeOrder = () =>
    Promise.reject(new AppError('OUT_OF_STOCK', 409, 'OUT_OF_STOCK', { size: 'M' }));
  const res = await makeHandler(deps)(post(body, userToken()));
  assertEquals(res.status, 409);
  assertEquals((await res.json()).error, {
    code: 'OUT_OF_STOCK',
    message: 'OUT_OF_STOCK',
    details: { size: 'M' },
  });
});

Deno.test('requests must be signed in and well-formed', async () => {
  const { deps } = fakes();
  const handler = makeHandler(deps);
  assertEquals((await handler(post(body))).status, 401);
  assertEquals((await handler(post({ ...body, items: [] }, userToken()))).status, 400);
  assertEquals((await handler(post('not json', userToken()))).status, 400);
});
