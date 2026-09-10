/**
 * Server-side AI usage quota — IVE-COMMERCIAL-ENTITLEMENTS-01.
 *
 * Reuses the already-tamper-proof public.profiles.role/monthly_limit
 * (see migration 20260907120001 — a client can never self-promote either
 * column) plus a new public.ai_usage counter (migration
 * 20260910190000_commercial_ai_quota.sql). All enforcement happens inside
 * two SECURITY DEFINER Postgres functions that derive identity from
 * auth.uid() only — never from a client-supplied user id, plan, or count.
 *
 * Contract: call reserveQuota(req) AFTER resolveAuthenticatedUser(req)
 * succeeds and BEFORE any Groq request. If result.allowed is false,
 * return quotaBlockedResponse() immediately — no Groq call. If the Groq
 * call then fails, call refundQuota(req) so the failed attempt doesn't
 * permanently cost the user a unit of their monthly allowance.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';

export interface QuotaResult {
  allowed: boolean;
  reason?: string;
  used?: number;
  limit?: number;
  role?: string;
}

/** Minimal shape reserveQuota/refundQuota need — lets tests inject a fake
 * client instead of hitting a real Supabase project. */
export interface QuotaClient {
  // deno-lint-ignore no-explicit-any
  rpc(fn: string): PromiseLike<{ data: any; error: unknown }>;
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

export async function reserveQuota(req: Request, client?: QuotaClient): Promise<QuotaResult> {
  const rpcClient = client ?? buildUserScopedClient(req);
  const { data, error } = await rpcClient.rpc('try_reserve_ai_quota');
  if (error || !data) return { allowed: false, reason: 'quota_service_error' };
  return data as QuotaResult;
}

/** Best-effort compensating decrement. Never throws -- a refund failure
 * must not turn into a 500 on top of an already-failed AI request. */
export async function refundQuota(req: Request, client?: QuotaClient): Promise<void> {
  try {
    const rpcClient = client ?? buildUserScopedClient(req);
    await rpcClient.rpc('refund_ai_quota');
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
  return new Response(
    JSON.stringify({ error: 'QUOTA_SERVICE_ERROR', message: 'Não foi possível verificar sua cota de IA.' }),
    { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
}
