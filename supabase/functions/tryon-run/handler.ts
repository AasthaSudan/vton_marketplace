// POST /tryon-run — Clothsy AI Try-On previews (Blueprint section 35).
//   {action: "run", product_id, variant_id, photo_id | preset_id, force?}
//   {action: "poll", job_id}
// Consent, ownership, eligibility and credits are checked in Postgres
// (start_tryon_job); a failed preview gives its credit back.

import { z } from 'zod';
import { requireUser } from '../_shared/auth.ts';
import { AppError, json, readBody, withErrors } from '../_shared/http.ts';
import type { TryOnProvider } from '../_shared/tryon/provider.ts';

const Body = z.discriminatedUnion('action', [
  z.object({
    action: z.literal('run'),
    product_id: z.string().uuid(),
    variant_id: z.string().uuid(),
    photo_id: z.string().uuid().nullish(),
    preset_id: z.string().uuid().nullish(),
    force: z.boolean().default(false),
  }),
  z.object({ action: z.literal('poll'), job_id: z.string().uuid() }),
]);

export interface StartedJob {
  job_id: string;
  cached: boolean;
  status: 'queued' | 'processing' | 'succeeded' | 'failed';
  result_path?: string | null;
  result_url?: string | null;
  garment_image_url?: string | null;
  credits: number;
}

export interface JobRow {
  id: string;
  user_id: string;
  status: StartedJob['status'];
  provider: string | null;
  provider_job_id: string | null;
  result_path: string | null;
  result_url: string | null;
  error_code: string | null;
  created_at: string;
}

export interface TryOnDeps {
  startJob(input: {
    userId: string;
    photoId: string | null;
    presetId: string | null;
    productId: string;
    variantId: string;
    force: boolean;
  }): Promise<StartedJob>;
  finishJob(input: {
    jobId: string;
    status: StartedJob['status'];
    provider?: string;
    providerJobId?: string;
    resultPath?: string;
    resultUrl?: string;
    errorCode?: string;
  }): Promise<void>;
  getJob(jobId: string): Promise<JobRow | null>;
  /// A short-lived URL the provider can fetch the person photo from.
  personImageUrl(userId: string, photoId: string | null, presetId: string | null): Promise<string>;
  productCategory(productId: string): Promise<string>;
  /// Copies a provider's result into private storage; returns its path.
  storeResult(userId: string, jobId: string, resultUrl: string): Promise<string>;
  credits(userId: string): Promise<number>;
  provider(): TryOnProvider;
  now?: () => Date;
}

/// A job still "processing" after this long is given up (credit refunded).
export const JOB_TIMEOUT_MS = 3 * 60 * 1000;

export function makeHandler(deps: TryOnDeps) {
  const now = deps.now ?? (() => new Date());

  async function finishWithResult(
    userId: string,
    jobId: string,
    provider: TryOnProvider,
    resultUrl: string,
  ) {
    // The mock returns a public catalogue image; real results are copied
    // into the shopper's private folder.
    if (provider.name === 'mock') {
      await deps.finishJob({ jobId, status: 'succeeded', provider: provider.name, resultUrl });
      return { result_url: resultUrl, result_path: null };
    }
    const resultPath = await deps.storeResult(userId, jobId, resultUrl);
    await deps.finishJob({ jobId, status: 'succeeded', provider: provider.name, resultPath });
    return { result_url: null, result_path: resultPath };
  }

  return withErrors(async (req) => {
    const caller = requireUser(req);
    const body = await readBody(req, Body);

    if (body.action === 'run') {
      if (!body.photo_id === !body.preset_id) {
        throw new AppError('INVALID_REQUEST', 400, 'Choose a photo or a model');
      }
      const started = await deps.startJob({
        userId: caller.userId,
        photoId: body.photo_id ?? null,
        presetId: body.preset_id ?? null,
        productId: body.product_id,
        variantId: body.variant_id,
        force: body.force,
      });
      if (started.cached) {
        return json({
          job_id: started.job_id,
          status: 'succeeded',
          cached: true,
          result_url: started.result_url ?? null,
          result_path: started.result_path ?? null,
          credits_remaining: started.credits,
        });
      }

      let provider: TryOnProvider;
      try {
        provider = deps.provider();
      } catch (e) {
        await deps.finishJob({ jobId: started.job_id, status: 'failed', errorCode: 'UNAVAILABLE' });
        throw e;
      }
      try {
        const submission = await provider.submit({
          personImageUrl: await deps.personImageUrl(
            caller.userId,
            body.photo_id ?? null,
            body.preset_id ?? null,
          ),
          garmentImageUrl: started.garment_image_url ?? '',
          category: await deps.productCategory(body.product_id),
          jobId: started.job_id,
        });
        if (submission.status === 'succeeded' && submission.resultUrl) {
          const result = await finishWithResult(
            caller.userId,
            started.job_id,
            provider,
            submission.resultUrl,
          );
          return json({
            job_id: started.job_id,
            status: 'succeeded',
            cached: false,
            ...result,
            credits_remaining: started.credits,
          });
        }
        if (submission.status === 'failed') throw new Error('provider refused the job');
        await deps.finishJob({
          jobId: started.job_id,
          status: 'processing',
          provider: provider.name,
          providerJobId: submission.providerJobId,
        });
        return json({
          job_id: started.job_id,
          status: 'processing',
          cached: false,
          credits_remaining: started.credits,
        });
      } catch (e) {
        console.error('try-on submit failed', e);
        await deps.finishJob({
          jobId: started.job_id,
          status: 'failed',
          errorCode: 'PROVIDER_ERROR',
        });
        throw new AppError('TRYON_FAILED', 502, "We couldn't create this preview");
      }
    }

    // poll
    const job = await deps.getJob(body.job_id);
    if (!job || job.user_id !== caller.userId) throw new AppError('JOB_NOT_FOUND', 404);
    const reply = async (status: string, extra: Record<string, unknown> = {}) =>
      json({
        job_id: job.id,
        status,
        ...extra,
        credits_remaining: await deps.credits(caller.userId),
      });

    if (job.status === 'succeeded') {
      return reply('succeeded', { result_url: job.result_url, result_path: job.result_path });
    }
    if (job.status === 'failed') return reply('failed', { error_code: job.error_code });

    if (now().getTime() - new Date(job.created_at).getTime() > JOB_TIMEOUT_MS) {
      await deps.finishJob({ jobId: job.id, status: 'failed', errorCode: 'TIMEOUT' });
      return reply('failed', { error_code: 'TIMEOUT' });
    }
    if (!job.provider_job_id) return reply('processing');

    const provider = deps.provider();
    const polled = await provider.poll(job.provider_job_id) as
      & Awaited<ReturnType<TryOnProvider['poll']>>
      & { nextProviderJobId?: string };
    if (polled.status === 'succeeded' && polled.resultUrl) {
      const result = await finishWithResult(caller.userId, job.id, provider, polled.resultUrl);
      return reply('succeeded', result);
    }
    if (polled.status === 'failed') {
      await deps.finishJob({ jobId: job.id, status: 'failed', errorCode: 'PROVIDER_ERROR' });
      return reply('failed', { error_code: 'PROVIDER_ERROR' });
    }
    if (polled.nextProviderJobId) {
      await deps.finishJob({
        jobId: job.id,
        status: 'processing',
        providerJobId: polled.nextProviderJobId,
      });
    }
    return reply('processing');
  });
}
