// Picks the try-on engine: FabricVTON when configured, the mock only where
// ALLOW_MOCK_PROVIDERS=true. Without one, Try-On says it is unavailable —
// shopping is never blocked.

import { AppError } from '../http.ts';
import { allowMocks, type Env } from '../env.ts';
import { FabricVtonProvider } from './fabricvton.ts';
import { MockTryOnProvider } from './mock.ts';
import type { TryOnProvider } from './provider.ts';

export function selectTryOnProvider(env: Env, http: typeof fetch = fetch): TryOnProvider {
  const url = env('FABRICVTON_API_URL');
  const key = env('FABRICVTON_API_KEY');
  if (url && key) return new FabricVtonProvider(url, key, http);
  if (allowMocks(env)) {
    return new MockTryOnProvider(Number(env('MOCK_TRYON_PENDING_POLLS') ?? '2'));
  }
  throw new AppError('TRYON_UNAVAILABLE', 503, 'Try-On is not available right now');
}
