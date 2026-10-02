// Who is calling. Tokens are verified before a function runs (by the local
// router, or by Supabase for functions with verify_jwt); here we only read
// the verified claims, or check the service key for internal callers.

import { AppError } from './http.ts';
import { timingSafeEqual } from './hmac.ts';

export interface Caller {
  userId: string;
  token: string;
}

export function bearerToken(req: Request): string | null {
  const header = req.headers.get('authorization') ?? '';
  const [scheme, token] = header.trim().split(/\s+/);
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
}

export function decodeClaims(token: string): Record<string, unknown> {
  const part = token.split('.')[1];
  if (!part) throw new AppError('AUTH_REQUIRED', 401, 'Invalid token');
  try {
    const padded = part.replace(/-/g, '+').replace(/_/g, '/').padEnd(
      Math.ceil(part.length / 4) * 4,
      '=',
    );
    return JSON.parse(atob(padded));
  } catch {
    throw new AppError('AUTH_REQUIRED', 401, 'Invalid token');
  }
}

/// The signed-in shopper making the request.
export function requireUser(req: Request): Caller {
  const token = bearerToken(req);
  if (!token) throw new AppError('AUTH_REQUIRED', 401, 'Sign in first');
  const claims = decodeClaims(token);
  if (claims.role !== 'authenticated' || typeof claims.sub !== 'string') {
    throw new AppError('AUTH_REQUIRED', 401, 'Sign in first');
  }
  return { userId: claims.sub, token };
}

/// Internal callers (pg_cron, other functions) present the service key.
export function requireServiceKey(req: Request, serviceKey: string): void {
  const token = bearerToken(req);
  if (!token || !serviceKey || !timingSafeEqual(token, serviceKey)) {
    throw new AppError('FORBIDDEN', 403, 'Service key required');
  }
}
