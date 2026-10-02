// Environment access. Mock providers are only allowed when
// ALLOW_MOCK_PROVIDERS=true, which is set for local development only.

export type Env = (name: string) => string | undefined;

export const denoEnv: Env = (name) => Deno.env.get(name) || undefined;

export function allowMocks(env: Env): boolean {
  return env('ALLOW_MOCK_PROVIDERS') === 'true';
}

export function requireEnv(env: Env, name: string): string {
  const value = env(name);
  if (!value) throw new Error(`${name} is not set`);
  return value;
}
