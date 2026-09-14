/**
 * Server-side AI usage quota — IVE-COMMERCIAL-ENTITLEMENTS-01.
 *
 * Reuses the already-tamper-proof public.profiles.role/monthly_limit
 * (see migration 20260907120001 — a client can never self-promote either
 * column) plus a new public.ai_usage counter (migration
 * 20260910190000_commercial_ai_quota.sql). All enforcement happens inside
 * SECURITY DEFINER Postgres functions that derive identity from
 * auth.uid() only — never from a client-supplied user id, plan, or count.
 *
 * Contract: call reserveQuota(req) AFTER resolveAuthenticatedUser(req)
 * succeeds and BEFORE any Groq request. If result.allowed is false,
 * return quotaBlockedResponse() immediately — no Groq call. If the Groq
 * call then fails, call refundQuota(req) so the failed attempt doesn't
 * permanently cost the user a unit of their monthly allowance.
 *
 * IVE-COMMERCIAL-QUOTA-HARDENING-13 — reserveQuota/refundQuota now accept
 * an optional idempotencyKey, forwarded to try_reserve_ai_quota(uuid)/
 * refund_ai_quota(uuid) (migration 20260918000000). This closes the gap
 * where a network retry, a second browser tab, or a client refresh after
 * the server already reserved but before the response arrived could
 * double-charge one intentional operation. The key is read from the
 * request body (idempotency_key) rather than a header, since every
 * caller already sends a JSON body and this avoids a second convention.
 * Backward compatible: omitting the key (or an existing caller not yet
 * updated) reproduces the exact pre-13 unconditional-reserve behavior —
 * see the migration's own comment for the removal point.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';

/** RFC 4122 UUID shape check — deliberately NOT trusting the DB's own
 * `uuid` cast to fail safely: a malformed key sent as a raw string would
 * otherwise reach Postgres as a type-cast error (a generic 500), rather
 * than the specific, safe "invalid_idempotency_key" rejection mission
 * Section 09's failure matrix calls for. */
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isValidIdempotencyKey(key: unknown): key is string {
  return typeof key === 'string' && UUID_PATTERN.test(key);
}

export interface QuotaResult {
  allowed: boolean;
  reason?: string;
  used?: number;
  limit?: number;
  role?: string;
  idempotentReplay?: boolean;
}

/** Minimal shape reserveQuota/refundQuota need — lets tests inject a fake
 * client instead of hitting a real Supabase project. Matches
 * supabase-js's real `.rpc(fn, params)` signature so no adapter is
 * needed for the real client. */
export interface QuotaClient {
  rpc(
    fn: string,
    // deno-lint-ignore no-explicit-any
    params?: Record<string, unknown>,
    // deno-lint-ignore no-explicit-any
  ): PromiseLike<{ data: any; error: unknown }>;
}

function extractToken(req: Request): string | null {
  const authHeader = req.headers.get('Authorization');
  const match = authHeader?.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() ?? null;
}

function buildUserScopedClient(req: Request): QuotaClient {
  const token = extractToken(req);
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!token || !supabaseUrl || !anonKey) {
    throw new Error('quota: missing bearer token or Supabase env config');
  }
  // Authorization header (the caller's own JWT, not the anon key itself)
  // is what makes auth.uid() resolve correctly inside the RPC functions --
  // this client authenticates the RPC call AS the calling user.
  return createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
}

/**
 * @param idempotencyKey Optional — the caller's own request body should
 * already have been parsed once by the Edge Function itself (a Request
 * body can only be read once); this function never re-reads req.json()
 * for it. Omit it (or pass undefined) to reproduce the exact pre-13
 * unconditional-reserve behavior. A value that doesn't look like a UUID
 * fails closed with 'invalid_idempotency_key' rather than reaching
 * Postgres as a type-cast error.
 */
export async function reserveQuota(
  req: Request,
  client?: QuotaClient,
  idempotencyKey?: string,
): Promise<QuotaResult> {
  if (idempotencyKey !== undefined && !isValidIdempotencyKey(idempotencyKey)) {
    return { allowed: false, reason: 'invalid_idempotency_key' };
  }
  const rpcClient = client ?? buildUserScopedClient(req);
  const { data, error } = await rpcClient.rpc(
    'try_reserve_ai_quota',
    idempotencyKey !== undefined ? { p_idempotency_key: idempotencyKey } : undefined,
  );
  if (error || !data) return { allowed: false, reason: 'quota_service_error' };
  return data as QuotaResult;
}

/** Best-effort compensating decrement. Never throws -- a refund failure
 * must not turn into a 500 on top of an already-failed AI request.
 * @param idempotencyKey Same contract as reserveQuota's — pass the SAME
 * key used for the reservation being refunded, so refund_ai_quota can
 * tie the refund to that specific reservation and stay idempotent itself
 * (mission Section 08: "at most one effective refund per reserved
 * operation"). A malformed key is silently ignored (best-effort), not
 * thrown, since a refund is already a failure-path cleanup step.
 */
export async function refundQuota(
  req: Request,
  client?: QuotaClient,
  idempotencyKey?: string,
): Promise<void> {
  try {
    const rpcClient = client ?? buildUserScopedClient(req);
    const key = idempotencyKey !== undefined && isValidIdempotencyKey(idempotencyKey)
      ? idempotencyKey
      : undefined;
    await rpcClient.rpc('refund_ai_quota', key !== undefined ? { p_idempotency_key: key } : undefined);
  } catch {
    // best-effort only
  }
}

export function quotaBlockedResponse(
  corsHeaders: Record<string, string>,
  result: QuotaResult,
): Response {
  if (result.reason === 'quota_exceeded') {
    return new Response(
      JSON.stringify({
        error: 'QUOTA_EXCEEDED',
        message: 'Limite mensal de análises de IA atingido.',
        used: result.used,
        limit: result.limit,
        role: result.role,
      }),
      { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
  if (result.reason === 'invalid_idempotency_key') {
    return new Response(
      JSON.stringify({
        error: 'INVALID_IDEMPOTENCY_KEY',
        message: 'Identificador de operação inválido.',
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
  return new Response(
    JSON.stringify({ error: 'QUOTA_SERVICE_ERROR', message: 'Não foi possível verificar sua cota de IA.' }),
    { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
}
