// Responses, CORS and errors shared by every Clothsy function.

export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, apikey, content-type, x-client-info, x-razorpay-signature, x-razorpay-event-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/// An error with a machine-readable code the app understands.
export class AppError extends Error {
  constructor(
    readonly code: string,
    readonly status = 400,
    message?: string,
    readonly details?: unknown,
  ) {
    super(message ?? code);
  }
}

// Order-service errors (raised in Postgres as P0001) and their HTTP status.
const statusByCode: Record<string, number> = {
  AUTH_REQUIRED: 401,
  ORDER_NOT_FOUND: 404,
  ADDRESS_NOT_FOUND: 404,
  PAYMENT_NOT_FOUND: 404,
  PHOTO_NOT_FOUND: 404,
  NO_CONSENT: 403,
  NO_CREDITS: 402,
  NOT_ELIGIBLE: 422,
  OUT_OF_STOCK: 409,
  PRICE_CHANGED: 409,
  IDEMPOTENCY_CONFLICT: 409,
  NOT_CANCELLABLE: 409,
  ORDER_AWAITING_PAYMENT: 409,
  NOT_PENDING: 409,
};

/// Turns a Postgres function error ({message: CODE, details: json}) into an
/// AppError.
export function fromDbError(
  error: { message?: string; details?: string | null; code?: string },
): AppError {
  const code = error.message ?? 'DB_ERROR';
  if (error.code === 'P0001' || code in statusByCode) {
    let details: unknown = error.details ?? undefined;
    try {
      details = error.details ? JSON.parse(error.details) : undefined;
    } catch {
      // Details are plain text.
    }
    return new AppError(code, statusByCode[code] ?? 422, code, details);
  }
  return new AppError('DB_ERROR', 500, 'Database error');
}

/// Wraps a handler: CORS preflight, POST only, and every failure as
/// {error: {code, message, details}}.
export function withErrors(
  handler: (req: Request) => Promise<Response>,
): (req: Request) => Promise<Response> {
  return async (req) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (req.method !== 'POST') {
      return json({ error: { code: 'METHOD_NOT_ALLOWED', message: 'Use POST' } }, 405);
    }
    try {
      return await handler(req);
    } catch (e) {
      if (e instanceof AppError) {
        return json({ error: { code: e.code, message: e.message, details: e.details } }, e.status);
      }
      console.error(e);
      return json({ error: { code: 'INTERNAL', message: 'Something went wrong' } }, 500);
    }
  };
}

/// Parses a JSON body with a zod-like schema.
export async function readBody<T>(
  req: Request,
  schema: {
    safeParse(v: unknown): { success: true; data: T } | { success: false; error: unknown };
  },
): Promise<T> {
  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    throw new AppError('INVALID_REQUEST', 400, 'Body must be JSON');
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) throw new AppError('INVALID_REQUEST', 400, 'Invalid request', parsed.error);
  return parsed.data;
}
