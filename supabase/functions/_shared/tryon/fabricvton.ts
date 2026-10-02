// FabricVTON try-on API — shaped for an async job API (submit, then poll).
// TODO(fabricvton): confirm endpoint paths, field names and statuses from the
// FabricVTON API docs once the account is set up; only this file changes.

import type { TryOnPoll, TryOnProvider, TryOnSubmission } from './provider.ts';

export class FabricVtonProvider implements TryOnProvider {
  readonly name = 'fabricvton' as const;

  constructor(
    private readonly baseUrl: string,
    private readonly apiKey: string,
    private readonly http: typeof fetch = fetch,
  ) {}

  private headers(extra: Record<string, string> = {}) {
    return {
      Authorization: `Bearer ${this.apiKey}`,
      'Content-Type': 'application/json',
      ...extra,
    };
  }

  private static status(raw: string | undefined): TryOnPoll['status'] {
    // TODO(fabricvton): map the provider's real status names.
    if (raw === 'succeeded' || raw === 'completed' || raw === 'success') return 'succeeded';
    if (raw === 'failed' || raw === 'error') return 'failed';
    return 'processing';
  }

  async submit(input: {
    personImageUrl: string;
    garmentImageUrl: string;
    category: string;
    jobId: string;
  }): Promise<TryOnSubmission> {
    const res = await this.http(`${this.baseUrl}/v1/tryon`, {
      method: 'POST',
      headers: this.headers({ 'Idempotency-Key': input.jobId }),
      body: JSON.stringify({
        person_image_url: input.personImageUrl,
        garment_image_url: input.garmentImageUrl,
        category: input.category,
      }),
    });
    if (!res.ok) throw new Error(`FabricVTON submit failed (${res.status})`);
    const data = await res.json() as { id: string; status?: string; result_url?: string };
    return {
      providerJobId: data.id,
      status: FabricVtonProvider.status(data.status),
      resultUrl: data.result_url,
    };
  }

  async poll(providerJobId: string): Promise<TryOnPoll> {
    const res = await this.http(
      `${this.baseUrl}/v1/tryon/${encodeURIComponent(providerJobId)}`,
      { headers: this.headers() },
    );
    if (!res.ok) throw new Error(`FabricVTON poll failed (${res.status})`);
    const data = await res.json() as { status?: string; result_url?: string; error?: string };
    return {
      status: FabricVtonProvider.status(data.status),
      resultUrl: data.result_url,
      error: data.error,
    };
  }
}
