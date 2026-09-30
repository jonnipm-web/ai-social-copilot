/**
 * Market-data cache — IV-QUANT-REAL-DATA-READINESS-03 (docs/quant/QUANT_CACHE_POLICY.md).
 *
 * THE CACHE MUST NOT LIE:
 *  - a hit returns the provider's ORIGINAL provenance (providerId, sourceAsOf,
 *    retrievedAt = providerRetrievedAt, adjustment) untouched, plus separate
 *    cache metadata (cacheServedAt, ageMs, state);
 *  - freshness of the DATA is still computed downstream from sourceAsOf/bars,
 *    never from the cache write time;
 *  - a stale entry is served ONLY when the provider fails, flagged
 *    STALE_CACHE (warning CACHE_STALE), and never beyond staleServeMs.
 * SCOPE: public market data from a provider only. USER_UPLOAD data is never
 * cached (no cross-user leakage of private datasets); entries are bound to
 * the provider id that produced them (no provider spoofing); keys are
 * canonical JSON tuples (no separator-injection collisions).
 * Implementation here: bounded in-memory LRU (tests / dev server). A shared
 * production store is an infra decision documented in QUANT_CACHE_POLICY.md.
 */
import { fail, ok, type QuantResult } from './errors.ts';
import { instrumentKey } from './instrument.ts';
import type { DataProvenance, Frequency } from './provenance.ts';
import type { HistoricalBarsRequest, MarketDataProvider, ProviderResponse, RawQuote } from './provider.ts';
import type { InstrumentIdentity } from './instrument.ts';
import type { RawBarInput } from './timeseries.ts';
import { calendarForMic } from './calendar.ts';

export type CacheState = 'FRESH_CACHE' | 'STALE_CACHE' | 'EXPIRED';

export interface CacheMeta {
  readonly status: 'HIT' | 'MISS' | 'STALE_FALLBACK';
  readonly state: CacheState | null;
  /** = provenance.retrievedAt of the provider call that filled the entry. */
  readonly providerRetrievedAt: string;
  readonly cacheServedAt: string;
  readonly ageMs: number;
}

export interface CachedProviderResponse extends ProviderResponse<RawBarInput[]> {
  readonly cache: CacheMeta;
}

export interface CachePolicy {
  /** Entry age ≤ freshTtlMs → served without calling the provider. */
  readonly freshTtlMs: number;
  /** Provider failed: entry age ≤ staleServeMs may be served, flagged STALE_CACHE. */
  readonly staleServeMs: number;
}

const MIN = 60_000, HOUR = 60 * MIN, DAY = 24 * HOUR;
export const DEFAULT_CACHE_POLICIES: Readonly<Record<Frequency, CachePolicy>> = {
  INTRADAY_1M: { freshTtlMs: MIN, staleServeMs: 5 * MIN },
  INTRADAY_5M: { freshTtlMs: 5 * MIN, staleServeMs: 20 * MIN },
  INTRADAY_1H: { freshTtlMs: 30 * MIN, staleServeMs: 3 * HOUR },
  DAILY: { freshTtlMs: 6 * HOUR, staleServeMs: 3 * DAY },
  WEEKLY: { freshTtlMs: DAY, staleServeMs: 7 * DAY },
  MONTHLY: { freshTtlMs: DAY, staleServeMs: 14 * DAY },
};

/** Period bound at the frequency's granularity (dates for DAILY+, minutes intraday), so equivalent requests share an entry. */
function periodBound(t: number, frequency: Frequency): string {
  const iso = new Date(t).toISOString();
  return frequency.startsWith('INTRADAY') ? iso.slice(0, 16) : iso.slice(0, 10);
}

/** Canonical cache key: every dimension that changes the bars, as a JSON tuple. */
export function marketCacheKey(providerId: string, providerVersion: string, req: HistoricalBarsRequest): string {
  const i: InstrumentIdentity = req.instrument;
  return JSON.stringify([
    'quant-market-v1', providerId, providerVersion, instrumentKey(i), i.isin ?? null, i.figi ?? null,
    req.frequency, req.adjustment, i.currency, calendarForMic(i.exchangeMic)?.id ?? 'CALENDAR_UNKNOWN',
    periodBound(req.fromT, req.frequency), periodBound(req.toT, req.frequency),
  ]);
}

interface Entry {
  readonly providerId: string;
  readonly data: readonly RawBarInput[];
  readonly provenance: DataProvenance;
  readonly storedAtMs: number;
}

export class InMemoryMarketCache {
  private readonly map = new Map<string, Entry>();
  constructor(private readonly maxEntries = 500) {}

  get(key: string): Entry | undefined {
    const e = this.map.get(key);
    if (e) {
      this.map.delete(key); // LRU touch
      this.map.set(key, e);
    }
    return e;
  }

  put(key: string, providerId: string, res: ProviderResponse<RawBarInput[]>, nowMs: number): QuantResult<null> {
    if (res.provenance.providerKind === 'USER_UPLOAD') return fail('INVALID_PARAMETER', 'user-uploaded data is never cached');
    if (res.provenance.providerId !== providerId) return fail('PROVIDER_MALFORMED', 'provenance does not belong to this provider');
    if (this.map.size >= this.maxEntries) this.map.delete(this.map.keys().next().value as string);
    this.map.set(key, { providerId, data: structuredClone(res.data), provenance: structuredClone(res.provenance), storedAtMs: nowMs });
    return ok(null);
  }

  size(): number {
    return this.map.size;
  }
}

export function cacheState(ageMs: number, policy: CachePolicy): CacheState {
  return ageMs <= policy.freshTtlMs ? 'FRESH_CACHE' : ageMs <= policy.staleServeMs ? 'STALE_CACHE' : 'EXPIRED';
}

/**
 * Read-through cache around a provider. Only historicalBars is cached; quotes
 * and lookups pass through (they are cheap and freshness-critical).
 */
export class CachingProvider implements MarketDataProvider {
  readonly id: string;
  readonly capabilities: MarketDataProvider['capabilities'];

  constructor(
    private readonly inner: MarketDataProvider,
    private readonly cache: InMemoryMarketCache,
    private readonly clock: () => number,
    private readonly providerVersion = '1',
    private readonly policies: Readonly<Record<Frequency, CachePolicy>> = DEFAULT_CACHE_POLICIES,
  ) {
    this.id = inner.id;
    this.capabilities = inner.capabilities;
  }

  lookupInstrument(query: string): Promise<QuantResult<InstrumentIdentity[]>> {
    return this.inner.lookupInstrument(query);
  }

  latestQuote(instrument: InstrumentIdentity): Promise<QuantResult<ProviderResponse<RawQuote>>> {
    return this.inner.latestQuote(instrument);
  }

  async historicalBars(req: HistoricalBarsRequest): Promise<QuantResult<CachedProviderResponse>> {
    const now = this.clock();
    const key = marketCacheKey(this.inner.id, this.providerVersion, req);
    const policy = this.policies[req.frequency];
    const hit = this.cache.get(key);
    const serve = (e: Entry, status: CacheMeta['status']): CachedProviderResponse => ({
      data: structuredClone(e.data) as RawBarInput[],
      provenance: structuredClone(e.provenance),
      cache: {
        status,
        state: cacheState(now - e.storedAtMs, policy),
        providerRetrievedAt: e.provenance.retrievedAt,
        cacheServedAt: new Date(now).toISOString(),
        ageMs: now - e.storedAtMs,
      },
    });
    if (hit && hit.providerId === this.inner.id && cacheState(now - hit.storedAtMs, policy) === 'FRESH_CACHE') {
      return ok(serve(hit, 'HIT'));
    }
    const res = await this.inner.historicalBars(req);
    if (res.ok) {
      const stored = this.cache.put(key, this.inner.id, res.value, now);
      if (!stored.ok) return stored;
      return ok({
        ...res.value,
        cache: { status: 'MISS', state: null, providerRetrievedAt: res.value.provenance.retrievedAt, cacheServedAt: new Date(now).toISOString(), ageMs: 0 },
      });
    }
    // Provider failed: a still-servable stale entry is better than nothing, but it says so.
    if (hit && hit.providerId === this.inner.id && cacheState(now - hit.storedAtMs, policy) === 'STALE_CACHE') {
      return ok(serve(hit, 'STALE_FALLBACK'));
    }
    return res;
  }
}
