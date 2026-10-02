// Local stand-in for the try-on engine: "processing" for a couple of polls,
// then the garment image as the result (what the app's mock shows too).

import type { TryOnPoll, TryOnProvider, TryOnSubmission } from './provider.ts';

export class MockTryOnProvider implements TryOnProvider {
  readonly name = 'mock' as const;

  /// [pendingPolls] polls answer "processing" before the result, so the
  /// app's polling loop is exercised. Encoded in the job id (no state).
  constructor(private readonly pendingPolls = 2) {}

  submit(input: { garmentImageUrl: string; jobId: string }): Promise<TryOnSubmission> {
    const payload = btoa(JSON.stringify({ g: input.garmentImageUrl, n: 0 }));
    if (this.pendingPolls <= 0) {
      return Promise.resolve({
        providerJobId: `mock_${payload}`,
        status: 'succeeded' as const,
        resultUrl: input.garmentImageUrl,
      });
    }
    return Promise.resolve({ providerJobId: `mock_${payload}`, status: 'processing' as const });
  }

  /// Each poll returns the next state; the caller stores the new job id.
  poll(providerJobId: string): Promise<TryOnPoll & { nextProviderJobId?: string }> {
    const state = JSON.parse(atob(providerJobId.replace(/^mock_/, ''))) as { g: string; n: number };
    if (state.n + 1 >= this.pendingPolls) {
      return Promise.resolve({ status: 'succeeded', resultUrl: state.g });
    }
    const next = `mock_${btoa(JSON.stringify({ g: state.g, n: state.n + 1 }))}`;
    return Promise.resolve({ status: 'processing', nextProviderJobId: next });
  }
}
