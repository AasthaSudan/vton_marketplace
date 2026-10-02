// Helpers for handler tests: signed-looking tokens and JSON requests.

const b64 = (value: unknown) =>
  btoa(JSON.stringify(value)).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');

/// A JWT-shaped token for [sub] (handlers trust claims verified upstream).
export function userToken(sub = '11111111-1111-1111-1111-111111111111'): string {
  return `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub, role: 'authenticated' })}.sig`;
}

export function post(body: unknown, token?: string, headers: Record<string, string> = {}): Request {
  return new Request('http://localhost/fn', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}
