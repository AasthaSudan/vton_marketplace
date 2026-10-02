// Local router for the Edge Runtime container (docker compose). Hosted
// Supabase does this itself: it verifies the caller's JWT (unless a function
// opts out) and runs the function. Here we do the same with JWT_SECRET.

// The router runs as the Edge Runtime's main service, which does not load
// the functions' import map, so its one dependency is imported inline.
// deno-lint-ignore no-import-prefix
import * as jose from 'jsr:@panva/jose@6';

// Functions that authenticate requests themselves.
const PUBLIC_FUNCTIONS = new Set(['razorpay-webhook']);

const secret = new TextEncoder().encode(Deno.env.get('JWT_SECRET') ?? '');

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
};

function error(status: number, code: string, message: string): Response {
  return Response.json({ error: { code, message } }, { status, headers: cors });
}

async function verified(req: Request): Promise<boolean> {
  const [scheme, token] = (req.headers.get('authorization') ?? '').trim().split(/\s+/);
  if (scheme?.toLowerCase() !== 'bearer' || !token) return false;
  try {
    await jose.jwtVerify(token, secret, { algorithms: ['HS256'] });
    return true;
  } catch {
    return false;
  }
}

Deno.serve(async (req: Request) => {
  const name = new URL(req.url).pathname.split('/').filter(Boolean)[0];
  if (!name || name === 'main' || name.startsWith('_')) {
    return error(404, 'NOT_FOUND', 'Function not found');
  }
  if (req.method !== 'OPTIONS' && !PUBLIC_FUNCTIONS.has(name) && !(await verified(req))) {
    return error(401, 'AUTH_REQUIRED', 'Missing or invalid authorization');
  }

  const servicePath = `/home/deno/functions/${name}`;
  try {
    await Deno.stat(`${servicePath}/index.ts`);
  } catch {
    return error(404, 'NOT_FOUND', 'Function not found');
  }

  try {
    // @ts-ignore: EdgeRuntime is a global of the Supabase Edge Runtime.
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath,
      memoryLimitMb: 150,
      workerTimeoutMs: 160_000,
      noModuleCache: false,
      importMapPath: '/home/deno/functions/deno.json',
      envVars: Object.entries(Deno.env.toObject()),
    });
    return await worker.fetch(req);
  } catch (e) {
    console.error(`function ${name} failed`, e);
    return error(500, 'FUNCTION_ERROR', 'Function failed (see logs)');
  }
});
