// quant-analyze — IV-QUANT-DATA-PLANE-AND-API-02.
//
// First read-only Quant API (module 'quant-analytics', READ_ONLY, INTERNAL).
// READINESS-03 adds two explicit contracts on the same endpoint, dispatched
// by contract_version (v1 unchanged): quant.analyze.multi.v1 (≤ 10 CSV
// series) and quant.analyze.watchlist.v1 (the caller's own watchlist, data
// from the server-side SYNTHETIC provider through the provenance cache; also
// requires the 'quant-watchlists' entitlement). No client-supplied URL.
// Order: authenticate → entitlement → method/body limits → strict schema →
// project ownership (if project_id) → data plane (CSV → canonical series →
// deterministic engine) → structured QuantAnalysisResult.
//
// Deliberately NOT here: any URL/remote fetch of market data (no SSRF
// surface), any LLM call (numbers come only from the engine), any write,
// any broker/order path, any quota reservation (no paid dependency; the
// resource bounds below are the protection — see QUANT_API_CONTRACT.md §6).
//
// NOT DEPLOYED (Quant Lab). Not on .github/deploy-allowlist.tsv.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { AuthClient, AuthenticatedUser, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from '../_shared/auth.ts';
import { EntitlementSubjectSource, requireModuleAccess } from '../_shared/entitlement.ts';
import type { QuotaClient } from '../_shared/quota.ts';
import { ANALYZE_CONTRACT_VERSION, MAX_ANALYZE_BODY_BYTES, parseAnalyzeRequest, parseInstrument, runAnalyze } from '../_shared/quant/api_contract.ts';
import type { InstrumentIdentity } from '../_shared/quant/instrument.ts';
import { CachingProvider, InMemoryMarketCache } from '../_shared/quant/market_cache.ts';
import {
  MULTI_CONTRACT_VERSION,
  parseMultiRequest,
  parseWatchlistAnalysisRequest,
  runMulti,
  runWatchlistAnalysis,
  WATCHLIST_ANALYSIS_CONTRACT_VERSION,
} from '../_shared/quant/multi_contract.ts';
import { MAX_SERIES_PER_ANALYSIS, type MultiSeriesResult } from '../_shared/quant/multi_series.ts';
import type { MarketDataProvider } from '../_shared/quant/provider.ts';
import { SyntheticInProcessProvider } from '../_shared/quant/synthetic_market.ts';
import type { WatchlistRow, WatchlistStore } from '../_shared/quant/watchlist_contract.ts';
import type { QuantErrorCode } from '../_shared/quant/errors.ts';
import { quantLogEvent } from '../_shared/quant/observability.ts';
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

export interface AnalyzeDeps {
  projectAccess?: ProjectAccessSource;
  /** Server clock (injected in tests). Used for provenance.retrievedAt and freshness only. */
  clock?: () => number;
  log?: (line: string) => void;
  rateLimiter?: QuantRateLimiter;
  /** quant.analyze.watchlist.v1: watchlist storage as the caller (tests inject a fake). */
  storeFor?: (accessToken: string) => WatchlistStore;
  /** quant.analyze.watchlist.v1: server-side market data (default: cached in-process SYNTHETIC provider). */
  marketProvider?: MarketDataProvider;
}

/** Per-instance LRU (Edge isolates are short-lived; provenance is preserved on every hit). */
const DEFAULT_MARKET_CACHE = new InMemoryMarketCache(256);

export async function handler(
  req: Request,
  authClient?: AuthClient,
  _quotaClient?: QuotaClient,
  subjectSource?: EntitlementSubjectSource,
  deps: AnalyzeDeps = {},
): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: quantCorsHeaders });

  let authUser: AuthenticatedUser;
  try {
    authUser = await resolveAuthenticatedUser(req, authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(quantCorsHeaders);
    throw e;
  }

  // Server-side entitlement for the READ_ONLY analytics module. 'ive-quant'
  // (CONSEQUENTIAL) is never served by an Edge Function (MP-09).
  const access = await requireModuleAccess(req, authUser, 'quant-analytics', quantCorsHeaders, subjectSource);
  if (!access.allowed) return access.response;

  const started = performance.now();
  const clock = deps.clock ?? (() => Date.now());
  const log = deps.log ?? ((line: string) => console.log(line));
  const cid = access.correlationId;
  let contract: string | null = null;
  const done = (res: Response, extra: {
    errorCode?: QuantErrorCode | null; analysisId?: string; providerId?: string; instruments?: number; bars?: number;
    period?: [string, string]; calcs?: string[]; freshness?: 'FRESH' | 'DELAYED' | 'STALE' | 'UNKNOWN'; hits?: number; misses?: number;
  }) => {
    log(JSON.stringify(quantLogEvent({
      analysisId: extra.analysisId ?? null,
      providerId: extra.providerId ?? 'user-csv',
      instrumentCount: extra.instruments ?? (extra.analysisId ? 1 : 0),
      contract,
      cacheHits: extra.hits ?? 0,
      cacheMisses: extra.misses ?? 0,
      datasetSize: extra.bars ?? 0,
      periodStart: extra.period?.[0] ?? null,
      periodEnd: extra.period?.[1] ?? null,
      calculations: extra.calcs ?? [],
      freshness: extra.freshness ?? null,
      latencyMs: performance.now() - started,
      errorCode: extra.errorCode ?? null,
    })));
    return res;
  };
  const failWith = (code: QuantHttpErrorCode, details?: Record<string, string | number | boolean | null>) =>
    done(quantError(code, cid, details), { errorCode: (code in HTTP_ONLY ? null : code) as QuantErrorCode | null });

  if (req.method !== 'POST') return failWith('METHOD_NOT_ALLOWED');
  // Rate limit BEFORE reading the (up to 6 MiB) body — server identity only.
  const limited = await enforceRateLimit(deps.rateLimiter ?? new SupabaseRateLimiter(), authUser.id, 'quant-analyze', bearerToken(req) ?? '', cid);
  if (limited) return done(limited, { errorCode: null });
  const body = await readJsonBody(req, MAX_ANALYZE_BODY_BYTES);
  if (!body.ok) return failWith(body.code, body.code === 'DATASET_TOO_LARGE' ? { maxBytes: MAX_ANALYZE_BODY_BYTES } : undefined);

  const version: unknown = typeof body.value === 'object' && body.value !== null && !Array.isArray(body.value)
    ? (body.value as Record<string, unknown>).contract_version
    : undefined;
  contract = typeof version === 'string' ? version : null;
  const token = bearerToken(req) ?? '';
  const checkProject = async (projectId: string | undefined): Promise<Response | null> => {
    if (!projectId) return null;
    let owns: boolean;
    try {
      owns = await (deps.projectAccess ?? new SupabaseProjectAccess()).ownsProject(authUser.id, projectId, token);
    } catch {
      return failWith('OWNERSHIP_UNAVAILABLE');
    }
    return owns ? null : failWith('PROJECT_ACCESS_DENIED');
  };
  const multiDone = (r: MultiSeriesResult, extra: { providerId: string; bars: number; hits?: number; misses?: number }) =>
    done(
      quantJson({ contract_version: version, correlation_id: cid, multi_analysis: r }),
      {
        analysisId: r.multiAnalysisId, providerId: extra.providerId, instruments: r.series.length, bars: extra.bars,
        period: r.alignment.start && r.alignment.end ? [r.alignment.start, r.alignment.end] : undefined,
        calcs: ['CORRELATION', ...(r.portfolio ? ['PORTFOLIO_BUY_AND_HOLD'] : [])], hits: extra.hits, misses: extra.misses,
      },
    );

  // ---- quant.analyze.multi.v1: up to 10 user CSV series (READ_ONLY, same module).
  if (version === MULTI_CONTRACT_VERSION) {
    const parsed = parseMultiRequest(body.value);
    if (!parsed.ok) return failWith(parsed.error.code, parsed.error.details);
    const denied = await checkProject(parsed.value.projectId);
    if (denied) return denied;
    const result = await runMulti(parsed.value, clock());
    if (!result.ok) return failWith(result.error.code, result.error.details);
    return multiDone(result.value, { providerId: 'user-csv', bars: result.value.series.reduce((n, s) => n + s.analysis.period.bars, 0) });
  }

  // ---- quant.analyze.watchlist.v1: the caller's OWN watchlist, server-side data only.
  if (version === WATCHLIST_ANALYSIS_CONTRACT_VERSION) {
    const parsed = parseWatchlistAnalysisRequest(body.value);
    if (!parsed.ok) return failWith(parsed.error.code, parsed.error.details);
    // Reading a watchlist is a 'quant-watchlists' capability: both modules must be granted.
    const wlAccess = await requireModuleAccess(req, authUser, 'quant-watchlists', quantCorsHeaders, subjectSource);
    if (!wlAccess.allowed) return done(wlAccess.response, { errorCode: 'ENTITLEMENT_DENIED' });
    let rows: WatchlistRow[];
    try {
      // Caller's JWT -> RLS is the isolation authority; user id filter on top.
      rows = await (deps.storeFor ?? ((t: string) => new SupabaseWatchlistStore(t)))(token).list(authUser.id);
    } catch {
      return failWith('INTERNAL_ERROR');
    }
    const wl = rows.find((w) => w.id === parsed.value.watchlistId);
    if (!wl) return failWith('INVALID_PARAMETER', { reason: 'NOT_FOUND', field: 'watchlist_id' });
    let items = wl.items;
    if (parsed.value.itemIds) {
      const byId = new Map(wl.items.map((it) => [it.id, it]));
      if (parsed.value.itemIds.some((id) => !byId.has(id))) return failWith('INVALID_PARAMETER', { reason: 'NOT_FOUND', field: 'item_ids' });
      items = parsed.value.itemIds.map((id) => byId.get(id)!);
    }
    if (items.length > MAX_SERIES_PER_ANALYSIS) return failWith('DATASET_TOO_LARGE', { max: MAX_SERIES_PER_ANALYSIS, reason: 'SELECT_ITEM_IDS' });
    const instruments: InstrumentIdentity[] = [];
    for (const it of items) {
      const inst = parseInstrument({
        asset_class: it.asset_class, symbol: it.symbol, currency: it.currency,
        ...(it.exchange_mic ? { exchange_mic: it.exchange_mic } : {}),
        ...(it.isin ? { isin: it.isin } : {}),
        ...(it.figi ? { figi: it.figi } : {}),
      });
      if (!inst.ok) return failWith('INVALID_INSTRUMENT');
      instruments.push(inst.value);
    }
    const provider = deps.marketProvider ?? new CachingProvider(new SyntheticInProcessProvider(clock), DEFAULT_MARKET_CACHE, clock);
    const result = await runWatchlistAnalysis(instruments, parsed.value, provider, clock());
    if (!result.ok) return failWith(result.error.code, result.error.details);
    const c = result.value.dataSource.cache;
    return multiDone(result.value, {
      providerId: result.value.dataSource.providerId,
      bars: result.value.series.reduce((n, s) => n + s.analysis.period.bars, 0),
      hits: c.hits + c.staleFallbacks, misses: c.misses,
    });
  }

  // ---- quant.analyze.v1 (unchanged contract).
  const parsed = parseAnalyzeRequest(body.value);
  if (!parsed.ok) return failWith(parsed.error.code, parsed.error.details);
  const denied = await checkProject(parsed.value.projectId);
  if (denied) return denied;

  const result = await runAnalyze(parsed.value, clock());
  if (!result.ok) return failWith(result.error.code, result.error.details);
  const a = result.value;
  return done(
    quantJson({ contract_version: ANALYZE_CONTRACT_VERSION, correlation_id: cid, analysis: a }),
    { analysisId: a.analysisId, bars: a.period.bars, period: [a.period.start, a.period.end], calcs: a.metrics.map((m) => m.id), freshness: a.dataSnapshot.freshness.state },
  );
}

/** Transport-only codes are not QuantErrorCodes; they log as error_code null + HTTP status. */
const HTTP_ONLY: Record<string, true> = { METHOD_NOT_ALLOWED: true, UNSUPPORTED_MEDIA_TYPE: true, INVALID_JSON: true, OWNERSHIP_UNAVAILABLE: true, INTERNAL_ERROR: true, RATE_LIMITED: true, RATE_LIMIT_UNAVAILABLE: true };

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
