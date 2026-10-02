import { assertEquals } from '@std/assert';
import { post } from '../_shared/testing.ts';
import { type CleanupDeps, makeHandler } from './handler.ts';

Deno.test('files are removed per bucket, then their rows', async () => {
  const removed: string[] = [];
  let purged: [string[], string[]] = [[], []];
  const deps: CleanupDeps = {
    serviceKey: 'key',
    candidates: () =>
      Promise.resolve([
        { kind: 'photo', id: 'p1', path: 'tryon-photos/u1/me.jpg' },
        { kind: 'job', id: 'j1', path: 'tryon-results/u1/j1.jpg' },
      ]),
    removeFiles: (bucket, paths) => {
      removed.push(...paths.map((p) => `${bucket}:${p}`));
      return Promise.resolve();
    },
    purgeRows: (photos, jobs) => {
      purged = [photos, jobs];
      return Promise.resolve();
    },
  };
  const res = await makeHandler(deps)(post({}, 'key'));
  assertEquals((await res.json()).purged, 2);
  assertEquals(removed, ['tryon-photos:u1/me.jpg', 'tryon-results:u1/j1.jpg']);
  assertEquals(purged, [['p1'], ['j1']]);
  assertEquals((await makeHandler(deps)(post({}, 'wrong'))).status, 403);
});
