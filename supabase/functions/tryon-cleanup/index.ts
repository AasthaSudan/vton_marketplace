import { denoEnv, requireEnv } from '../_shared/env.ts';
import { rpc, serviceClient } from '../_shared/supabase.ts';
import { makeHandler, type PurgeCandidate } from './handler.ts';

const service = serviceClient(denoEnv);

Deno.serve(makeHandler({
  serviceKey: requireEnv(denoEnv, 'SUPABASE_SERVICE_ROLE_KEY'),
  candidates: (limit) =>
    rpc<PurgeCandidate[]>(service, 'tryon_purge_candidates', { p_limit: limit }),
  removeFiles: async (bucket, paths) => {
    const { error } = await service.storage.from(bucket).remove(paths);
    if (error) throw error;
  },
  purgeRows: async (photoIds, jobIds) => {
    await rpc(service, 'tryon_purge_rows', { p_photo_ids: photoIds, p_job_ids: jobIds });
  },
}));
