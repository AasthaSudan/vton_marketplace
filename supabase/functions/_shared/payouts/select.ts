// Picks the payout rail: RazorpayX when its keys and source account are set,
// the mock only where ALLOW_MOCK_PROVIDERS=true, otherwise none.

import { AppError } from '../http.ts';
import { allowMocks, type Env } from '../env.ts';
import { MockPayoutProvider } from './mock.ts';
import type { PayoutProvider } from './provider.ts';
import { RazorpayXProvider } from './razorpayx.ts';

export function selectPayoutProvider(env: Env, http: typeof fetch = fetch): PayoutProvider {
  const keyId = env('RAZORPAYX_KEY_ID');
  const keySecret = env('RAZORPAYX_KEY_SECRET');
  const account = env('RAZORPAYX_ACCOUNT_NUMBER');
  if (keyId && keySecret && account) return new RazorpayXProvider(keyId, keySecret, account, http);
  if (allowMocks(env)) return new MockPayoutProvider();
  throw new AppError('PAYOUTS_NOT_CONFIGURED', 503, 'Seller payouts are not available');
}
