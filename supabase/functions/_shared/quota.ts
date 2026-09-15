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
 * an optional (idempotencyKey, operationType) pair, forwarded to
 * try_reserve_ai_quota(uuid, text)/refund_ai_quota(uuid, text) (migration
 * 20260918000000). This closes the gap where a network retry, a second
 * browser tab, or a client refresh after the server already reserved but
 * before the response arrived could double-charge one intentional
 * operation. The idempotencyKey is read from the request body
 * (idempotency_key) by the calling Edge Function, since every caller
 * already sends a JSON body and this avoids a second convention.
 *
 * operationType is DELIBERATELY NOT read from the client's request body —
 * each Edge Function passes its OWN hardcoded name (e.g. 'gap-analysis')
 * as a literal. It exists to scope the reservation ledger so one key
 * cannot be replayed against a DIFFERENT Edge Function and be mistaken
 * for that operation's own already-successful reservation (Codex Gate 1
 * finding on this mission's first draft: a client-suppliable
 * operation_type would have reopened the same bypass by letting the
 * caller simply lie about which operation a replayed key belongs to).
 *
 * Backward compatible: omitting both (or an existing caller not yet
 * updated) reproduces the exact pre-13 unconditional-reserve behavior —
 * see the migration's own comment for the removal point.
 *
 * refundQuota takes a reservationId (the reserve call's own
 * QuotaResult.reservationId), NOT the idempotency key/operation pair —
 * Codex Gate 2 finding on this mission's second draft: refunding by
 * re-deriving "the current active row for this (key, operation, period)
 * tuple" let a DELAYED DUPLICATE refund call match a NEWER reservation
 * created by a legitimate retry after the original was already refunded,
 * silently un-charging a real, successful AI call. A reservation's own
 * immutable id can never be reused by a later attempt, so a delayed
 * duplicate naming an old id is a safe no-op instead.
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
  /** Present whenever an idempotency key was used for this reservation
   * (fresh or replayed). Pass this — not the idempotency key/operation
   * pair — to refundQuota if the downstream action then fails. */
  reservationId?: string;
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
 * @param operationType Required whenever idempotencyKey is supplied — a
 * literal constant the CALLING Edge Function hardcodes for itself (never
 * read from the client's request). Missing/empty while a key is present
 * fails closed with 'invalid_request' rather than reaching Postgres with
 * a NULL that would silently defeat the reservation ledger's uniqueness
 * guarantee (see migration 20260918000000's own comment on this).
 */
export async function reserveQuota(
  req: Request,
  client?: QuotaClient,
  idempotencyKey?: string,
  operationType?: string,
): Promise<QuotaResult> {
  if (idempotencyKey !== undefined) {
    if (!isValidIdempotencyKey(idempotencyKey)) {
      return { allowed: false, reason: 'invalid_idempotency_key' };
    }
    if (!operationType || operationType.trim() === '') {
      return { allowed: false, reason: 'invalid_request' };
    }
  }
  const rpcClient = client ?? buildUserScopedClient(req);
  const { data, error } = await rpcClient.rpc(
    'try_reserve_ai_quota',
    idempotencyKey !== undefined
      ? { p_idempotency_key: idempotencyKey, p_operation_type: operationType }
      : undefined,
  );
  if (error || !data) return { allowed: false, reason: 'quota_service_error' };
  // The RPC returns snake_case JSON (reservation_id, idempotent_replay) —
  // map explicitly rather than blindly casting, or reservationId would
  // silently be undefined at runtime despite compiling fine.
  const raw = data as Record<string, unknown>;
  return {
    allowed: raw.allowed as boolean,
    reason: raw.reason as string | undefined,
    used: raw.used as number | undefined,
    limit: raw.limit as number | undefined,
    role: raw.role as string | undefined,
    idempotentReplay: raw.idempotent_replay as boolean | undefined,
    reservationId: raw.reservation_id as string | undefined,
  };
}

/** Best-effort compensating decrement. Never throws -- a refund failure
 * must not turn into a 500 on top of an already-failed AI request.
 * @param reservationId The SAME reserveQuota call's own
 * `result.reservationId` — NOT the idempotency key or operation type.
 * Refunding by the reservation's own immutable id (rather than
 * re-deriving "the current row for this key+operation+period") is what
 * keeps a delayed duplicate refund from ever matching a DIFFERENT, later
 * reservation created by a legitimate retry (Codex Gate 2 finding — see
 * this file's own top-of-file doc comment). Omit it to reproduce the
 * legacy unconditional decrement (pre-13 behavior / a caller that never
 * used an idempotency key to begin with).
 */
export async function refundQuota(
  req: Request,
  client?: QuotaClient,
  reservationId?: string,
): Promise<void> {
  try {
    const rpcClient = client ?? buildUserScopedClient(req);
    await rpcClient.rpc(
      'refund_ai_quota',
      reservationId !== undefined ? { p_reservation_id: reservationId } : undefined,
    );
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
  if (result.reason === 'invalid_idempotency_key' || result.reason === 'invalid_request') {
    return new Response(
      JSON.stringify({
        error: result.reason === 'invalid_idempotency_key'
          ? 'INVALID_IDEMPOTENCY_KEY'
          : 'INVALID_REQUEST',
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
