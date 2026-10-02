// Picks the payment provider from the environment: Razorpay when its keys
// are set, the mock only where ALLOW_MOCK_PROVIDERS=true, otherwise none.

import { AppError } from '../http.ts';
import { allowMocks, type Env } from '../env.ts';
import { MockPaymentProvider } from './mock.ts';
import type { PaymentProvider } from './provider.ts';
import { RazorpayProvider } from './razorpay.ts';

export function selectPaymentProvider(env: Env, http: typeof fetch = fetch): PaymentProvider {
  const keyId = env('RAZORPAY_KEY_ID');
  const keySecret = env('RAZORPAY_KEY_SECRET');
  if (keyId && keySecret) {
    return new RazorpayProvider(keyId, keySecret, env('RAZORPAY_WEBHOOK_SECRET') ?? '', http);
  }
  if (allowMocks(env)) return new MockPaymentProvider(env('MOCK_WEBHOOK_SECRET'));
  throw new AppError('PAYMENTS_NOT_CONFIGURED', 503, 'Online payments are not available');
}
