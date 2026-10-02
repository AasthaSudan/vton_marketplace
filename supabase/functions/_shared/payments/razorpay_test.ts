import { assert, assertEquals, assertFalse, assertRejects } from '@std/assert';
import { RazorpayProvider } from './razorpay.ts';
import { MockPaymentProvider } from './mock.ts';
import { selectPaymentProvider } from './select.ts';
import { AppError } from '../http.ts';

const ORDER = 'order_TEST000000001';
const PAYMENT = 'pay_TEST000000001';
const WEBHOOK_BODY =
  '{"entity":"event","event":"payment.captured","payload":{"payment":{"entity":{"id":"pay_TEST000000001","order_id":"order_TEST000000001","amount":449900,"currency":"INR","status":"captured"}}}}';

const provider = (http: typeof fetch = fetch) =>
  new RazorpayProvider(
    'rzp_test_key',
    'clothsy_test_key_secret',
    'clothsy_test_webhook_secret',
    http,
  );

Deno.test('payment signatures are HMAC(order_id|payment_id)', async () => {
  const p = provider();
  assert(
    await p.verifyPaymentSignature({
      providerOrderId: ORDER,
      paymentId: PAYMENT,
      signature: '28bec8bfe704360e9f37bc209048e882b60231119f2515147fa36777a5084884',
    }),
  );
  assertFalse(
    await p.verifyPaymentSignature({
      providerOrderId: ORDER,
      paymentId: 'pay_TEST000000002',
      signature: '28bec8bfe704360e9f37bc209048e882b60231119f2515147fa36777a5084884',
    }),
  );
});

Deno.test('webhook signatures are HMAC of the raw body', async () => {
  const p = provider();
  const signature = '82cf45cc91179b4f4e732bc5fc90bc62ce0704bfeca49f66c008d35c3a76c333';
  assert(await p.verifyWebhookSignature(WEBHOOK_BODY, signature));
  assertFalse(await p.verifyWebhookSignature(WEBHOOK_BODY.replace('449900', '1'), signature));
  assertFalse(await p.verifyWebhookSignature(WEBHOOK_BODY, null));
});

Deno.test('orders and refunds call the Razorpay API with basic auth', async () => {
  const calls: { url: string; init?: RequestInit }[] = [];
  const http = (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init });
    const body = String(url).endsWith('/orders')
      ? { id: 'order_abc' }
      : { id: 'rfnd_abc', status: 'processed' };
    return Promise.resolve(new Response(JSON.stringify(body), { status: 200 }));
  };
  const p = provider(http as typeof fetch);

  assertEquals(
    (await p.createOrder({ amount: 449900, receipt: 'CLY-1' })).providerOrderId,
    'order_abc',
  );
  assertEquals(
    (await p.refund({ paymentId: PAYMENT, amount: 1000, receipt: 'refund-1' })).providerRefundId,
    'rfnd_abc',
  );
  assertEquals(calls[0].url, 'https://api.razorpay.com/v1/orders');
  assertEquals(JSON.parse(String(calls[0].init?.body)).amount, 449900);
  assertEquals(
    (calls[0].init?.headers as Record<string, string>).Authorization,
    `Basic ${btoa('rzp_test_key:clothsy_test_key_secret')}`,
  );
  assertEquals(calls[1].url, `https://api.razorpay.com/v1/payments/${PAYMENT}/refund`);
});

Deno.test('API errors surface as failures', async () => {
  const http = () =>
    Promise.resolve(
      new Response(JSON.stringify({ error: { description: 'Bad amount' } }), { status: 400 }),
    );
  await assertRejects(
    () => provider(http as typeof fetch).createOrder({ amount: 1, receipt: 'x' }),
    Error,
    'Bad amount',
  );
});

Deno.test('provider selection: Razorpay keys, else local mock, else unavailable', () => {
  const env = (vars: Record<string, string>) => (name: string) => vars[name];
  assertEquals(
    selectPaymentProvider(env({ RAZORPAY_KEY_ID: 'k', RAZORPAY_KEY_SECRET: 's' })).name,
    'razorpay',
  );
  assertEquals(selectPaymentProvider(env({ ALLOW_MOCK_PROVIDERS: 'true' })).name, 'mock');
  try {
    selectPaymentProvider(env({}));
    throw new Error('expected an error');
  } catch (e) {
    assert(e instanceof AppError);
    assertEquals(e.status, 503);
  }
});

Deno.test('the mock only accepts mock payments', async () => {
  const mock = new MockPaymentProvider();
  assert(await mock.verifyPaymentSignature({ paymentId: 'pay_mock_1' } as never));
  assertFalse(await mock.verifyPaymentSignature({ paymentId: 'pay_real_1' } as never));
});
