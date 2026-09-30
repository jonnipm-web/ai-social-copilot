/**
 * Server adapters for the Quant Edge Functions — IV-QUANT-DATA-PLANE-AND-API-02.
 *
 * Everything with I/O lives here, NOT in _shared/quant/ (which must stay
 * pure: tripwires QB-02/QB-03). Contents:
 *   - bounded JSON body reading (413 before the body can exhaust memory)
 *   - the structured error envelope + HTTP mapping
 *   - ProjectAccessSource: "does the CALLER own this project?" via the
 *     caller's own JWT (public.projects RLS: auth.uid() = user_id)
 *   - SupabaseWatchlistStore: watchlist persistence via the caller's JWT, so
 *     Postgres RLS is the data-isolation authority
 * No service-role client is used anywhere in Quant.
 */
import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';
import type { QuantErrorCode, QuantErrorDetails } from './quant/errors.ts';
import { httpStatusFor, type TransportErrorCode } from './quant/api_contract.ts';
import type { InstrumentIdentity } from './quant/instrument.ts';
import { itemColumns, type WatchlistRow, type WatchlistStore } from './quant/watchlist_contract.ts';
import { FixedWindowCounter, type RateLimitBucket, type RateLimitDecision } from './quant/rate_limit_policy.ts';

export const quantCorsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-correlation-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export type QuantHttpErrorCode = QuantErrorCode | TransportErrorCode | 'OWNERSHIP_UNAVAILABLE';

export function quantError(code: QuantHttpErrorCode, correlationId: string, details?: QuantErrorDetails): Response {
  const status = code === 'OWNERSHIP_UNAVAILABLE' ? 503 : httpStatusFor(code);
  const body: Record<string, unknown> = { error: code, correlation_id: correlationId };
  if (details) body.details = details;
  return new Response(JSON.stringify(body), { status, headers: { ...quantCorsHeaders, 'Content-Type': 'application/json' } });
}

export function quantJson(body: unknown): Response {
  return new Response(JSON.stringify(body), { status: 200, headers: { ...quantCorsHeaders, 'Content-Type': 'application/json' } });
}

export function bearerToken(req: Request): string | null {
  const m = (req.headers.get('Authorization') ?? '').match(/^Bearer\s+(.+)$/i);
  return m?.[1]?.trim() || null;
}

/**
 * Reads a JSON body with a hard byte cap. Content-Length is checked first;
 * the stream is also counted, so a lying or absent Content-Length cannot
 * bypass the cap.
 */
export async function readJsonBody(
  req: Request,
  maxBytes: number,
): Promise<{ ok: true; value: unknown } | { ok: false; code: 'DATASET_TOO_LARGE' | 'UNSUPPORTED_MEDIA_TYPE' | 'INVALID_JSON' }> {
  // Exact media type (parameters such as charset allowed) — Codex CXN-02.
  const mediaType = (req.headers.get('Content-Type') ?? '').split(';')[0].trim().toLowerCase();
  if (mediaType !== 'application/json') return { ok: false, code: 'UNSUPPORTED_MEDIA_TYPE' };
  const declared = Number(req.headers.get('Content-Length') ?? '0');
  if (Number.isFinite(declared) && declared > maxBytes) return { ok: false, code: 'DATASET_TOO_LARGE' };
  if (!req.body) return { ok: false, code: 'INVALID_JSON' };
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel().catch(() => {});
      return { ok: false, code: 'DATASET_TOO_LARGE' };
    }
    chunks.push(value);
  }
  const buf = new Uint8Array(total);
  let off = 0;
  for (const c of chunks) {
    buf.set(c, off);
    off += c.byteLength;
  }
  try {
    return { ok: true, value: JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(buf)) };
  } catch {
    return { ok: false, code: 'INVALID_JSON' };
  }
}

function callerClient(accessToken: string): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!url || !anonKey) throw new Error('quant server misconfigured');
  return createClient(url, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
}

// ------------------------------------------------------------------ project ownership

export interface ProjectAccessSource {
  /** true = the caller owns the project; false = not found or not theirs. Throws on lookup failure (caller fails closed). */
  ownsProject(userId: string, projectId: string, accessToken: string): Promise<boolean>;
}

/** RLS on public.projects (auth.uid() = user_id) + an explicit user_id filter (defense in depth). */
export class SupabaseProjectAccess implements ProjectAccessSource {
  async ownsProject(userId: string, projectId: string, accessToken: string): Promise<boolean> {
    const { data, error } = await callerClient(accessToken)
      .from('projects').select('id').eq('id', projectId).eq('user_id', userId).maybeSingle();
    if (error) throw new Error('project lookup failed');
    return data !== null;
  }
}

// ------------------------------------------------------------------ watchlist persistence

const WATCHLIST_SELECT = 'id,name,project_id,created_at,updated_at,items:quant_watchlist_items(id,instrument_key,asset_class,symbol,exchange_mic,currency,isin,figi,created_at)';

/** Every call runs as the caller (JWT → RLS). `userId` only adds explicit filters. */
export class SupabaseWatchlistStore implements WatchlistStore {
  private readonly db: SupabaseClient;
  constructor(accessToken: string) {
    this.db = callerClient(accessToken);
  }

  async list(userId: string): Promise<WatchlistRow[]> {
    const { data, error } = await this.db.from('quant_watchlists').select(WATCHLIST_SELECT).eq('user_id', userId)
      .order('created_at', { ascending: true }).limit(50);
    if (error) throw new Error('watchlist list failed');
    return (data ?? []) as unknown as WatchlistRow[];
  }

  async countWatchlists(userId: string): Promise<number> {
    const { count, error } = await this.db.from('quant_watchlists').select('id', { count: 'exact', head: true }).eq('user_id', userId);
    if (error) throw new Error('watchlist count failed');
    return count ?? 0;
  }

  async create(userId: string, name: string, projectId: string | null): Promise<WatchlistRow> {
    const { data, error } = await this.db.from('quant_watchlists')
      .insert({ user_id: userId, name, project_id: projectId }).select(WATCHLIST_SELECT).single();
    if (error) throw new Error(error.message?.includes('QUANT_WATCHLIST_LIMIT') ? 'LIMIT' : 'watchlist create failed');
    return data as unknown as WatchlistRow;
  }

  async rename(userId: string, watchlistId: string, name: string): Promise<boolean> {
    const { data, error } = await this.db.from('quant_watchlists').update({ name })
      .eq('id', watchlistId).eq('user_id', userId).select('id');
    if (error) throw new Error('watchlist rename failed');
    return (data ?? []).length === 1;
  }

  async remove(userId: string, watchlistId: string): Promise<boolean> {
    const { data, error } = await this.db.from('quant_watchlists').delete().eq('id', watchlistId).eq('user_id', userId).select('id');
    if (error) throw new Error('watchlist delete failed');
    return (data ?? []).length === 1;
  }

  async itemCount(userId: string, watchlistId: string): Promise<number | null> {
    const owned = await this.db.from('quant_watchlists').select('id').eq('id', watchlistId).eq('user_id', userId).maybeSingle();
    if (owned.error) throw new Error('watchlist lookup failed');
    if (!owned.data) return null;
    const { count, error } = await this.db.from('quant_watchlist_items').select('id', { count: 'exact', head: true }).eq('watchlist_id', watchlistId);
    if (error) throw new Error('item count failed');
    return count ?? 0;
  }

  async addItem(userId: string, watchlistId: string, instrument: InstrumentIdentity): Promise<'ADDED' | 'DUPLICATE' | 'NOT_FOUND' | 'LIMIT'> {
    const { instrument_key: _generated, ...cols } = itemColumns(instrument);
    const { error } = await this.db.from('quant_watchlist_items').insert({ ...cols, watchlist_id: watchlistId, user_id: userId });
    if (!error) return 'ADDED';
    if (error.code === '23505') return 'DUPLICATE';
    if (error.message?.includes('QUANT_WATCHLIST_ITEM_LIMIT')) return 'LIMIT';
    if (error.code === '42501') return 'NOT_FOUND';
    throw new Error('item insert failed');
  }

  async removeItem(userId: string, watchlistId: string, itemId: string): Promise<boolean> {
    const { data, error } = await this.db.from('quant_watchlist_items').delete()
      .eq('id', itemId).eq('watchlist_id', watchlistId).eq('user_id', userId).select('id');
    if (error) throw new Error('item delete failed');
    return (data ?? []).length === 1;
  }
}

// ------------------------------------------------------------------ rate limiting

export interface QuantRateLimiter {
  /** Counts one hit for the SERVER-derived user. Throws when the counter store is unavailable. */
  hit(userId: string, bucket: RateLimitBucket, accessToken: string): Promise<RateLimitDecision>;
}

/**
 * Production authority: public.quant_rate_limit_hit via the caller's JWT.
 * The SQL function derives identity from auth.uid() and holds the limits;
 * `userId` is not sent (it could not be trusted by the database anyway).
 */
export class SupabaseRateLimiter implements QuantRateLimiter {
  async hit(_userId: string, bucket: RateLimitBucket, accessToken: string): Promise<RateLimitDecision> {
    const { data, error } = await callerClient(accessToken).rpc('quant_rate_limit_hit', { p_bucket: bucket });
    const d = data as Record<string, unknown> | null;
    if (error || !d || typeof d.allowed !== 'boolean' || typeof d.limit !== 'number') throw new Error('rate limit store unavailable');
    return {
      allowed: d.allowed,
      limit: d.limit,
      remaining: typeof d.remaining === 'number' ? d.remaining : 0,
      retryAfterSeconds: typeof d.retry_after_seconds === 'number' ? Math.max(1, d.retry_after_seconds) : 60,
    };
  }
}

/** Tests and the local Lab dev server only (not shared across isolates). */
export class InMemoryRateLimiter implements QuantRateLimiter {
  private readonly counter: FixedWindowCounter;
  constructor(clock: () => number = () => Date.now()) {
    this.counter = new FixedWindowCounter(clock);
  }
  // deno-lint-ignore require-await
  async hit(userId: string, bucket: RateLimitBucket): Promise<RateLimitDecision> {
    return this.counter.hit(userId, bucket);
  }
}

/**
 * Applies the limiter. Returns a ready Response when the request must stop:
 * 429 RATE_LIMITED (+ Retry-After) when over the limit, 503
 * RATE_LIMIT_UNAVAILABLE when the counter store fails — FAIL CLOSED
 * (QUANT_RATE_LIMIT_POLICY.md §4). Returns null when the request may proceed.
 */
export async function enforceRateLimit(
  limiter: QuantRateLimiter,
  userId: string,
  bucket: RateLimitBucket,
  accessToken: string,
  correlationId: string,
): Promise<Response | null> {
  let decision: RateLimitDecision;
  try {
    decision = await limiter.hit(userId, bucket, accessToken);
  } catch {
    return quantError('RATE_LIMIT_UNAVAILABLE', correlationId);
  }
  if (decision.allowed) return null;
  const res = quantError('RATE_LIMITED', correlationId, { retry_after_seconds: decision.retryAfterSeconds, limit: decision.limit });
  res.headers.set('Retry-After', String(decision.retryAfterSeconds));
  return res;
}
