// POST /tryon-cleanup — deletes try-on photos and previews that expired or
// that the shopper deleted (Blueprint: a visible retention period, one-tap
// deletion). pg_cron runs it hourly. Files go through the Storage API.

import { requireServiceKey } from '../_shared/auth.ts';
import { json, withErrors } from '../_shared/http.ts';

export interface PurgeCandidate {
  kind: 'photo' | 'job';
  id: string;
  path: string;
}

export interface CleanupDeps {
  serviceKey: string;
  candidates(limit: number): Promise<PurgeCandidate[]>;
  removeFiles(bucket: string, paths: string[]): Promise<void>;
  purgeRows(photoIds: string[], jobIds: string[]): Promise<void>;
}

export function makeHandler(deps: CleanupDeps) {
  return withErrors(async (req) => {
    requireServiceKey(req, deps.serviceKey);
    const candidates = await deps.candidates(200);

    const byBucket = new Map<string, string[]>();
    for (const c of candidates) {
      const [bucket, ...rest] = c.path.split('/');
      byBucket.set(bucket, [...(byBucket.get(bucket) ?? []), rest.join('/')]);
    }
    for (const [bucket, paths] of byBucket) {
      for (let i = 0; i < paths.length; i += 100) {
        await deps.removeFiles(bucket, paths.slice(i, i + 100));
      }
    }
    await deps.purgeRows(
      candidates.filter((c) => c.kind === 'photo').map((c) => c.id),
      candidates.filter((c) => c.kind === 'job').map((c) => c.id),
    );
    return json({ purged: candidates.length });
  });
}
