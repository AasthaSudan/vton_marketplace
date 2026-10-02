// What Clothsy needs from a virtual try-on engine.

export type TryOnProviderStatus = 'processing' | 'succeeded' | 'failed';

export interface TryOnSubmission {
  providerJobId: string;
  status: TryOnProviderStatus;
  resultUrl?: string;
}

export interface TryOnPoll {
  status: TryOnProviderStatus;
  resultUrl?: string;
  error?: string;
}

export interface TryOnProvider {
  readonly name: 'fabricvton' | 'mock';
  /// Starts a preview. [personImageUrl] must be reachable by the provider
  /// (a short-lived signed URL); [jobId] doubles as an idempotency key.
  submit(input: {
    personImageUrl: string;
    garmentImageUrl: string;
    category: string;
    jobId: string;
  }): Promise<TryOnSubmission>;
  poll(providerJobId: string): Promise<TryOnPoll>;
}
