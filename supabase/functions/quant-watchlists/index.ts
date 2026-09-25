// quant-watchlists — IV-QUANT-DATA-PLANE-AND-API-02.
//
// Watchlist CRUD for module 'quant-watchlists' (REVERSIBLE user state,
// INTERNAL) — split from the READ_ONLY 'quant-analytics' module because it
// persists data (Codex CXA-02). The database enforces the same INTERNAL
// boundary for direct PostgREST access (Codex CXA-01).
// authenticate → entitlement → body limits → strict schema →
// project ownership (create with project_id) → storage as the CALLER (their
// JWT, so Postgres RLS from migration 20260924000000 is the isolation
// authority; no service role). Instruments are validated with the
// Foundation's canonical identity before they reach the database.
//
// Logging: operation, item count, outcome, latency, error code — never the
// instruments, names or ids themselves (QUANT_SECURITY_MODEL.md §6).
//
// NOT DEPLOYED (Quant Lab). Not on .github/deploy-allowlist.tsv.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { AuthClient, AuthenticatedUser, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from '../_shared/auth.ts';
import { EntitlementSubjectSource, requireModuleAccess } from '../_shared/entitlement.ts';
import type { QuotaClient } from '../_shared/quota.ts';
import {
  MAX_WATCHLIST_BODY_BYTES,
  MAX_WATCHLIST_ITEMS,
  MAX_WATCHLISTS_PER_USER,
  parseWatchlistAction,
  WATCHLISTS_CONTRACT_VERSION,
  type WatchlistStore,
} from '../_shared/quant/watchlist_contract.ts';
import {
  bearerToken,
  enforceRateLimit,
  type ProjectAccessSource,
  quantCorsHeaders,
  quantError,
  type QuantHttpErrorCode,
  quantJson,
  type QuantRateLimiter,
  readJsonBody,
  SupabaseProjectAccess,
  SupabaseRateLimiter,
  SupabaseWatchlistStore,
} from '../_shared/quant_server.ts';

export interface WatchlistDeps {
  projectAccess?: ProjectAccessSource;
  /** Built per request from the caller's token (tests inject a fake). */
  storeFor?: (accessToken: string) => WatchlistStore;
  log?: (line: string) => void;
  rateLimiter?: QuantRateLimiter;
}

const OPS = new Set(['list', 'create', 'rename', 'delete', 'add_item', 'remove_item']);

export async function handler(
  req: Request,
  authClient?: AuthClient,
  _quotaClient?: QuotaClient,
  subjectSource?: EntitlementSubjectSource,
  deps: WatchlistDeps = {},
): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: quantCorsHeaders });

  let authUser: AuthenticatedUser;
  try {
    authUser = await resolveAuthenticatedUser(req, authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(quantCorsHeaders);
    throw e;
  }

  const access = await requireModuleAccess(req, authUser, 'quant-watchlists', quantCorsHeaders, subjectSource);
  if (!access.allowed) return access.response;

  const started = performance.now();
  const cid = access.correlationId;
  const log = deps.log ?? ((line: string) => console.log(line));
  let op = 'unknown';
  const done = (res: Response, itemCount: number | null, errorCode: string | null) => {
    log(JSON.stringify({
      event: 'quant_watchlist',
      operation: OPS.has(op) ? op : 'unknown',
      item_count: itemCount,
      success: res.status < 400,
      status: res.status,
      error_code: errorCode,
      latency_ms: Math.round(performance.now() - started),
      correlation_id: cid,
    }));
    return res;
  };
  const failWith = (code: QuantHttpErrorCode, details?: Record<string, string | number | boolean | null>) =>
    done(quantError(code, cid, details), null, code);

  if (req.method !== 'POST') return failWith('METHOD_NOT_ALLOWED');
  const token = bearerToken(req) ?? '';
  const limiter = deps.rateLimiter ?? new SupabaseRateLimiter();
  // Codex Final (P1): an ingress limit BEFORE the body is read/parsed, so
  // malformed or unknown-action requests cannot bypass rate limiting. The
  // action-specific bucket (read/write) is applied after parsing.
  const ingress = await enforceRateLimit(limiter, authUser.id, 'quant-watchlists-ingress', token, cid);
  if (ingress) return done(ingress, null, 'RATE_LIMITED');
  const body = await readJsonBody(req, MAX_WATCHLIST_BODY_BYTES);
  if (!body.ok) return failWith(body.code);
  const parsed = parseWatchlistAction(body.value);
  if (!parsed.ok) return failWith(parsed.error.code, parsed.error.details);
  const action = parsed.value;
  op = action.action;

  const bucket = action.action === 'list' ? 'quant-watchlists-read' : 'quant-watchlists-write';
  const limited = await enforceRateLimit(limiter, authUser.id, bucket, token, cid);
  if (limited) return done(limited, null, 'RATE_LIMITED');
  const store = (deps.storeFor ?? ((t: string) => new SupabaseWatchlistStore(t)))(token);
  const uid = authUser.id;
  const ok = (payload: Record<string, unknown>, items: number | null) =>
    done(quantJson({ contract_version: WATCHLISTS_CONTRACT_VERSION, correlation_id: cid, ...payload }), items, null);

  try {
    switch (action.action) {
      case 'list': {
        const rows = await store.list(uid);
        return ok({ watchlists: rows }, rows.reduce((n, w) => n + w.items.length, 0));
      }
      case 'create': {
        if (action.projectId) {
          let owns: boolean;
          try {
            owns = await (deps.projectAccess ?? new SupabaseProjectAccess()).ownsProject(uid, action.projectId, token);
          } catch {
            return failWith('OWNERSHIP_UNAVAILABLE');
          }
          if (!owns) return failWith('PROJECT_ACCESS_DENIED');
        }
        if ((await store.countWatchlists(uid)) >= MAX_WATCHLISTS_PER_USER) {
          return failWith('DATASET_TOO_LARGE', { max: MAX_WATCHLISTS_PER_USER });
        }
        try {
          return ok({ watchlist: await store.create(uid, action.name, action.projectId ?? null) }, 0);
        } catch (e) {
          if (e instanceof Error && e.message === 'LIMIT') return failWith('DATASET_TOO_LARGE', { max: MAX_WATCHLISTS_PER_USER });
          throw e;
        }
      }
      case 'rename':
        return (await store.rename(uid, action.watchlistId, action.name)) ? ok({ updated: true }, null) : failWith('INVALID_PARAMETER', { reason: 'NOT_FOUND' });
      case 'delete':
        return (await store.remove(uid, action.watchlistId)) ? ok({ deleted: true }, null) : failWith('INVALID_PARAMETER', { reason: 'NOT_FOUND' });
      case 'add_item': {
        const count = await store.itemCount(uid, action.watchlistId);
        if (count === null) return failWith('INVALID_PARAMETER', { reason: 'NOT_FOUND' });
        if (count >= MAX_WATCHLIST_ITEMS) return failWith('DATASET_TOO_LARGE', { max: MAX_WATCHLIST_ITEMS });
        const r = await store.addItem(uid, action.watchlistId, action.instrument);
        if (r === 'ADDED') return ok({ added: true }, count + 1);
        if (r === 'DUPLICATE') return failWith('INVALID_PARAMETER', { reason: 'DUPLICATE_INSTRUMENT' });
        if (r === 'LIMIT') return failWith('DATASET_TOO_LARGE', { max: MAX_WATCHLIST_ITEMS });
        return failWith('INVALID_PARAMETER', { reason: 'NOT_FOUND' });
      }
      case 'remove_item':
        return (await store.removeItem(uid, action.watchlistId, action.itemId)) ? ok({ removed: true }, null) : failWith('INVALID_PARAMETER', { reason: 'NOT_FOUND' });
    }
  } catch {
    return failWith('INTERNAL_ERROR');
  }
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
