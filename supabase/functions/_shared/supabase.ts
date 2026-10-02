// Supabase clients for functions: the service role for trusted work, or a
// client acting as the signed-in shopper (so auth.uid() and row level
// security apply inside Postgres).

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { type Env, requireEnv } from './env.ts';
import { fromDbError } from './http.ts';

const options = { auth: { persistSession: false, autoRefreshToken: false } };

export function serviceClient(env: Env): SupabaseClient {
  return createClient(
    requireEnv(env, 'SUPABASE_URL'),
    requireEnv(env, 'SUPABASE_SERVICE_ROLE_KEY'),
    options,
  );
}

export function userClient(env: Env, token: string): SupabaseClient {
  return createClient(requireEnv(env, 'SUPABASE_URL'), requireEnv(env, 'SUPABASE_ANON_KEY'), {
    ...options,
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
}

/// Calls a Postgres function and throws its error as an AppError.
export async function rpc<T>(
  client: SupabaseClient,
  fn: string,
  args: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await client.rpc(fn, args);
  if (error) throw fromDbError(error);
  return data as T;
}
