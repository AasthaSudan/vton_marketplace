import { assertEquals } from '@std/assert';
import { hmacSha256Hex } from '../_shared/hmac.ts';
import { RazorpayProvider } from '../_shared/payments/razorpay.ts';
import { post } from '../_shared/testing.ts';
import { makeHandler, type WebhookDeps } from './handler.ts';

const SECRET = 'clothsy_test_webhook_secret';
const event = {
  entity: 'event',
  event: 'payment.captured',
  payload: {
    payment: {
      entity: {
        id: 'pay_1',
        order_id: 'order_1',
        amount: 449900,
        currency: 'INR',
        status: 'captured',
      },
    },
  },
};

function fakes() {
  const stored = new Map<string, { processed: boolean }>();
  const confirmed: string[] = [];
  let failNext = false;
  const deps: WebhookDeps = {
    provider: () => new RazorpayProvider('k', 's', SECRET),
    storeEvent: (id) => {
      if (!stored.has(id)) stored.set(id, { processed: false });
      return Promise.resolve(!stored.get(id)!.processed);
    },
    markProcessed: (id) => {
      stored.get(id)!.processed = true;
      return Promise.resolve();
    },
    markFailed: () => Promise.resolve(),
    findPayment: (providerOrderId) =>
      Promise.resolve(providerOrderId === 'order_1' ? { order_id: 'ours', amount: 449900 } : null),
    confirmPayment: (input) => {
      if (failNext) {
        failNext = false;
        return Promise.reject(new Error('db down'));
      }
      confirmed.push(input.providerPaymentId);
      return Promise.resolve({});
    },
  };
  return { deps, confirmed, failOnce: () => (failNext = true) };
}

async function signed(body: unknown, eventId = 'evt_1') {
  const raw = JSON.stringify(body);
  return post(raw, undefined, {
    'x-razorpay-signature': await hmacSha256Hex(SECRET, raw),
    'x-razorpay-event-id': eventId,
  });
}

Deno.test('a captured payment confirms the order once, however often it is sent', async () => {
  const { deps, confirmed } = fakes();
  const handler = makeHandler(deps);
  assertEquals((await handler(await signed(event))).status, 200);
  const again = await handler(await signed(event));
  assertEquals((await again.json()).duplicate, true);
  assertEquals(confirmed, ['pay_1']);
});

Deno.test('unsigned or tampered webhooks are rejected and stored nowhere', async () => {
  const { deps, confirmed } = fakes();
  const handler = makeHandler(deps);
  assertEquals((await handler(post(JSON.stringify(event)))).status, 401);
  const forged = await signed(event);
  const tampered = new Request(forged.url, {
    method: 'POST',
    headers: forged.headers,
    body: JSON.stringify({ ...event, event: 'refund.processed' }),
  });
  assertEquals((await handler(tampered)).status, 401);
  assertEquals(confirmed, []);
});

Deno.test('a processing failure returns 500 so Razorpay retries, then succeeds', async () => {
  const { deps, confirmed, failOnce } = fakes();
  const handler = makeHandler(deps);
  failOnce();
  assertEquals((await handler(await signed(event))).status, 500);
  assertEquals((await handler(await signed(event))).status, 200);
  assertEquals(confirmed, ['pay_1']);
});

Deno.test('events for orders that are not ours are acknowledged', async () => {
  const { deps, confirmed } = fakes();
  const other = structuredClone(event);
  other.payload.payment.entity.order_id = 'order_elsewhere';
  assertEquals((await makeHandler(deps)(await signed(other, 'evt_2'))).status, 200);
  assertEquals(confirmed, []);
});
