import { assertEquals } from '@std/assert';
import { AppError } from '../_shared/http.ts';
import { MockTryOnProvider } from '../_shared/tryon/mock.ts';
import { post, userToken } from '../_shared/testing.ts';
import { JOB_TIMEOUT_MS, type JobRow, makeHandler, type TryOnDeps } from './handler.ts';

const USER = '11111111-1111-1111-1111-111111111111';
const run = {
  action: 'run',
  product_id: '66666666-6666-6666-6666-666666666666',
  variant_id: '77777777-7777-7777-7777-777777777777',
  preset_id: '88888888-8888-8888-8888-888888888888',
};

function fakes(pendingPolls = 2) {
  const jobs = new Map<string, JobRow>();
  let credits = 15;
  let clock = new Date('2026-10-02T10:00:00Z');
  const deps: TryOnDeps = {
    startJob: () => {
      if (credits <= 0) return Promise.reject(new AppError('NO_CREDITS', 402));
      credits--;
      const id = crypto.randomUUID();
      jobs.set(id, {
        id,
        user_id: USER,
        status: 'processing',
        provider: null,
        provider_job_id: null,
        result_path: null,
        result_url: null,
        error_code: null,
        created_at: clock.toISOString(),
      });
      return Promise.resolve({
        job_id: id,
        cached: false,
        status: 'processing',
        garment_image_url: 'https://example.com/blazer.jpg',
        credits,
      });
    },
    finishJob: (input) => {
      const job = jobs.get(input.jobId)!;
      if (job.status !== 'processing') return Promise.resolve();
      job.status = input.status;
      job.provider = input.provider ?? job.provider;
      job.provider_job_id = input.providerJobId ?? job.provider_job_id;
      job.result_url = input.resultUrl ?? job.result_url;
      job.error_code = input.errorCode ?? null;
      if (input.status === 'failed') credits++;
      return Promise.resolve();
    },
    getJob: (id) => Promise.resolve(jobs.get(id) ?? null),
    personImageUrl: () => Promise.resolve('https://example.com/person.jpg'),
    productCategory: () => Promise.resolve('Women'),
    storeResult: (_u, jobId) => Promise.resolve(`${USER}/${jobId}.jpg`),
    credits: () => Promise.resolve(credits),
    provider: () => new MockTryOnProvider(pendingPolls),
    now: () => clock,
  };
  return {
    deps,
    credits: () => credits,
    advance: (ms: number) => (clock = new Date(clock.getTime() + ms)),
  };
}

Deno.test('a preview runs, is polled, and lands with the garment image', async () => {
  const { deps } = fakes(2);
  const handler = makeHandler(deps);
  const started = await (await handler(post(run, userToken(USER)))).json();
  assertEquals(started.status, 'processing');

  const poll = { action: 'poll', job_id: started.job_id };
  assertEquals((await (await handler(post(poll, userToken(USER)))).json()).status, 'processing');
  const done = await (await handler(post(poll, userToken(USER)))).json();
  assertEquals(done.status, 'succeeded');
  assertEquals(done.result_url, 'https://example.com/blazer.jpg');
  assertEquals(done.credits_remaining, 14);
});

Deno.test('a provider failure gives the credit back', async () => {
  const { deps, credits } = fakes();
  deps.provider = () => {
    const p = new MockTryOnProvider();
    p.submit = () => Promise.reject(new Error('engine down'));
    return p;
  };
  const res = await makeHandler(deps)(post(run, userToken(USER)));
  assertEquals(res.status, 502);
  assertEquals(credits(), 15);
});

Deno.test('jobs that never finish time out and refund the credit', async () => {
  const { deps, credits, advance } = fakes(99);
  const handler = makeHandler(deps);
  const started = await (await handler(post(run, userToken(USER)))).json();
  advance(JOB_TIMEOUT_MS + 1000);
  const res =
    await (await handler(post({ action: 'poll', job_id: started.job_id }, userToken(USER)))).json();
  assertEquals(res.status, 'failed');
  assertEquals(res.error_code, 'TIMEOUT');
  assertEquals(credits(), 15);
});

Deno.test("nobody can poll another shopper's job", async () => {
  const { deps } = fakes();
  const handler = makeHandler(deps);
  const started = await (await handler(post(run, userToken(USER)))).json();
  const res = await handler(
    post(
      { action: 'poll', job_id: started.job_id },
      userToken('99999999-9999-9999-9999-999999999999'),
    ),
  );
  assertEquals(res.status, 404);
});

Deno.test('out of credits and bad requests are explained', async () => {
  const { deps } = fakes();
  deps.startJob = () => Promise.reject(new AppError('NO_CREDITS', 402));
  const handler = makeHandler(deps);
  assertEquals((await handler(post(run, userToken(USER)))).status, 402);
  const both = { ...run, photo_id: '99999999-9999-9999-9999-999999999999' };
  assertEquals((await handler(post(both, userToken(USER)))).status, 400);
});
