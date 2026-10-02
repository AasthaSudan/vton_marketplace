import { denoEnv } from '../_shared/env.ts';
import { AppError } from '../_shared/http.ts';
import { rpc, serviceClient } from '../_shared/supabase.ts';
import { selectTryOnProvider } from '../_shared/tryon/select.ts';
import { type JobRow, makeHandler, type StartedJob } from './handler.ts';

const service = serviceClient(denoEnv);

Deno.serve(makeHandler({
  startJob: (input) =>
    rpc<StartedJob>(service, 'start_tryon_job', {
      p_user: input.userId,
      p_photo_id: input.photoId,
      p_preset_id: input.presetId,
      p_product_id: input.productId,
      p_variant_id: input.variantId,
      p_force: input.force,
    }),
  finishJob: async (input) => {
    await rpc(service, 'finish_tryon_job', {
      p_job_id: input.jobId,
      p_status: input.status,
      p_provider: input.provider ?? null,
      p_provider_job_id: input.providerJobId ?? null,
      p_result_path: input.resultPath ?? null,
      p_result_url: input.resultUrl ?? null,
      p_error_code: input.errorCode ?? null,
    });
  },
  getJob: async (jobId) => {
    const { data } = await service.from('tryon_jobs')
      .select(
        'id, user_id, status, provider, provider_job_id, result_path, result_url, error_code, created_at',
      )
      .eq('id', jobId).is('deleted_at', null).maybeSingle();
    return data as JobRow | null;
  },
  personImageUrl: async (userId, photoId, presetId) => {
    if (presetId) {
      const { data } = await service.from('tryon_presets').select('image_url')
        .eq('id', presetId).single();
      return data?.image_url ?? '';
    }
    const { data: photo } = await service.from('tryon_photos').select('storage_path')
      .eq('id', photoId).eq('user_id', userId).is('deleted_at', null).maybeSingle();
    if (!photo) throw new AppError('PHOTO_NOT_FOUND', 404);
    const { data, error } = await service.storage.from('tryon-photos')
      .createSignedUrl(photo.storage_path, 600);
    if (error || !data) throw new AppError('PHOTO_NOT_FOUND', 404);
    return data.signedUrl;
  },
  productCategory: async (productId) => {
    const { data } = await service.from('products').select('category').eq('id', productId)
      .single();
    return data?.category ?? '';
  },
  storeResult: async (userId, jobId, resultUrl) => {
    const res = await fetch(resultUrl);
    if (!res.ok) throw new Error(`could not download result (${res.status})`);
    const path = `${userId}/${jobId}.jpg`;
    const { error } = await service.storage.from('tryon-results').upload(
      path,
      await res.arrayBuffer(),
      { contentType: res.headers.get('content-type') ?? 'image/jpeg', upsert: true },
    );
    if (error) throw error;
    return path;
  },
  credits: async (userId) => {
    const { data } = await service.from('tryon_credit_balances').select('balance')
      .eq('user_id', userId).maybeSingle();
    return data?.balance ?? 0;
  },
  provider: () => selectTryOnProvider(denoEnv),
}));
